import json
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
from datetime import datetime
import os
from reportlab.lib.pagesizes import A4
from reportlab.platypus import Image, Paragraph, SimpleDocTemplate, Spacer, Table, TableStyle, PageBreak
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib import colors
from others.database import MongoDB

# -----------------------------
# 1. CHARGEMENT & NETTOYAGE
# -----------------------------
def load_and_clean_data(raw_data):
    df = pd.json_normalize(raw_data)
    # Handle both possible timestamp formats
    if 'timestamp.$date' in df.columns:
        df['timestamp'] = pd.to_datetime(df['timestamp.$date'])
    elif 'timestamp' in df.columns:
        df['timestamp'] = pd.to_datetime(df['timestamp'])
    else:
        raise ValueError("No timestamp field found in data!")

    df['latitude'] = df['location.latitude']
    df['longitude'] = df['location.longitude']
    df['bin_name'] = df['name']

    df = df[['bin_id', 'bin_name', 'timestamp', 'latitude', 'longitude', 'trash_type',
             'trash_level', 'gaz_level', 'humidity', 'temperature',
             'volume', 'water_level', 'weight']]
    return df

# -----------------------------
# 2. ANALYSES VISUELLES
# -----------------------------
def plot_distributions(df):
    fig, axs = plt.subplots(2, 2, figsize=(20, 20))
    sns.set_theme(style="whitegrid")

    sns.histplot(df['trash_level'], bins=20, kde=True, ax=axs[0, 0], color='#4CAF50')
    axs[0, 0].set_title("Distribution du niveau de remplissage")

    sns.histplot(df['gaz_level'], bins=20, kde=True, ax=axs[0, 1], color='#F44336')
    axs[0, 1].set_title("Distribution du niveau de gaz")

    sns.boxplot(x='trash_type', y='trash_level', data=df, ax=axs[1, 0], palette='Set3')
    axs[1, 0].set_title("Remplissage par type de déchet")

    df['trash_type'].value_counts().plot.pie(autopct='%1.1f%%', ax=axs[1, 1], colors=sns.color_palette('Pastel1'))
    axs[1, 1].set_title("Répartition des types de déchets")
    axs[1, 1].set_ylabel("")

    plt.tight_layout()
    plt.savefig("rapport_analytique.png")
    plt.close()

def plot_time_analysis(df):
    df['hour'] = df['timestamp'].dt.hour
    df['date'] = df['timestamp'].dt.date

    fig, axs = plt.subplots(1, 2, figsize=(14, 5))
    sns.lineplot(data=df.groupby('hour')['trash_level'].mean(), ax=axs[0], color='#4CAF50')
    axs[0].set_title("Remplissage moyen par heure")
    axs[0].set_xlabel("Heure")

    sns.lineplot(data=df.groupby('date')['trash_level'].mean(), ax=axs[1], color='#2196F3')
    axs[1].set_title("Remplissage moyen par jour")
    axs[1].set_xlabel("Date")

    plt.tight_layout()
    plt.savefig("analyse_temporelle.png")
    plt.close()

def plot_correlation_heatmap(df):
    plt.figure(figsize=(10, 6))
    corr = df[['trash_level', 'gaz_level', 'temperature', 'humidity', 'water_level', 'weight']].corr()
    sns.heatmap(corr, annot=True, cmap='coolwarm', fmt=".2f", linewidths=0.5)
    plt.title("Corrélation entre les variables")
    plt.tight_layout()
    plt.savefig("correlation_heatmap.png")
    plt.close()

# -----------------------------
# 3. GÉNÉRATION DU RAPPORT PDF
# -----------------------------
def table_bacs_critiques(df):
    critiques = df[df['trash_level'] > 85][['bin_id', 'bin_name', 'trash_level', 'gaz_level']]
    if not critiques.empty:
        data = [list(critiques.columns)] + critiques.values.tolist()
        t = Table(data, colWidths=[80]*4)
        t.setStyle(TableStyle([
            ('BACKGROUND', (0,0), (-1,0), colors.red),
            ('TEXTCOLOR', (0,0), (-1,0), colors.white),
            ('GRID', (0,0), (-1,-1), 0.5, colors.grey)
        ]))
        return t
    return None

def generate_nlp_summary(df):
    mean_level = round(df['trash_level'].mean(), 1)
    max_level = df['trash_level'].max()
    min_level = df['trash_level'].min()
    std_level = round(df['trash_level'].std(), 1)
    critical_bins = len(df[df['trash_level'] > 85])
    resume = (
        f"<b>🧠 RÉSUMÉ AUTOMATIQUE PAR NLP</b><br/>"
        f"Le niveau moyen de remplissage est de {mean_level}%. "
        f"Le remplissage maximum atteint {max_level}%, tandis que le minimum est {min_level}%. "
        f"L'écart type est de {std_level}%, indiquant une variation importante. "
        f"Nombre de bacs critiques : {critical_bins}. "
        f"Des anomalies sont à surveiller."
    )
    return resume

def export_pdf_report(df, filename="statics/rapport_final_fr.pdf"):
    styles = getSampleStyleSheet()
    styles.add(ParagraphStyle(name='TitreCentre', parent=styles['Title'], alignment=1))
    styles.add(ParagraphStyle(name='EnteteSection', fontSize=14, leading=16, spaceAfter=12, textColor=colors.HexColor("#2E4053"), alignment=1))
    styles.add(ParagraphStyle(name='TexteCorps', fontSize=10, leading=14))

    doc = SimpleDocTemplate(filename, pagesize=A4)
    story = []

    # LOGO de l'application
    logo_path = "statics/logo_app.png"
    if os.path.exists(logo_path):
        logo = Image(logo_path, width=80, height=80)
        logo.hAlign = 'CENTER'
        story.append(logo)
        story.append(Spacer(1, 10))

    # TITRE
    story.append(Paragraph("<b>RAPPORT D'ANALYSE INTELLIGENTE</b><br/>GESTION DES DÉCHETS", styles['TitreCentre']))
    story.append(Spacer(1, 18))

    # CONTENU
    summary_text = f'''
    <font size=10>
    <b>📊 RÉSUMÉ DE L’ANALYSE</b><br/>
    Période analysée : 12/06/2025 - 24/06/2025<br/>
    Nombre total de bacs suivis : {df['bin_id'].nunique()}<br/>
    Total des enregistrements analysés : {len(df)}<br/><br/>

    <b>📈 INDICATEURS PRINCIPAUX</b><br/>
    • Remplissage moyen : {round(df["trash_level"].mean(), 1)}%<br/>
    • Écart type : {round(df["trash_level"].std(), 1)}%<br/>
    • Remplissage maximum : {df["trash_level"].max()}%<br/>
    • Remplissage minimum : {df["trash_level"].min()}%<br/><br/>

    <b>🚨 ANALYSE DES ALERTES</b><br/>
    • Nombre de bacs en alerte (>85%) : {len(df[df["trash_level"] > 85])}<br/>
    • État général du système : 🟢 Fonctionnement normal<br/><br/>

    <b>⏰ ANALYSE DU TEMPS</b><br/>
    • Heure la plus critique : {df['timestamp'].dt.hour.mode()[0]}h<br/>
    • Tendance observée : en augmentation<br/><br/>

    <b>🌡️ ANALYSE ENVIRONNEMENTALE</b><br/>
    • Corrélation (remplissage/température) : {round(df["trash_level"].corr(df["temperature"]), 3)}<br/>
    • Corrélation (remplissage/humidité) : {round(df["trash_level"].corr(df["humidity"]), 3)}<br/>
    • Corrélation (remplissage/gaz) : {round(df["trash_level"].corr(df["gaz_level"]), 3)}<br/><br/>

    <b>✅ CONCLUSION</b><br/>
    Rapport basé sur {len(df)} relevés issus de {df['bin_id'].nunique()} bacs connectés. La situation est globalement stable avec quelques anomalies à surveiller.
    </font>
    '''
    story.append(Paragraph(summary_text, styles['TexteCorps']))
    story.append(PageBreak())

    # GRAPHIQUES
    story.append(Paragraph("📊 ANALYSES VISUELLES", styles['EnteteSection']))
    if os.path.exists("rapport_analytique.png"):
        story.append(Image("rapport_analytique.png", width=500, height=400))

    if os.path.exists("analyse_temporelle.png"):
        story.append(PageBreak())
        story.append(Paragraph("📆 ANALYSE TEMPORELLE", styles['EnteteSection']))
        story.append(Image("analyse_temporelle.png", width=500, height=300))

    if os.path.exists("correlation_heatmap.png"):
        story.append(PageBreak())
        story.append(Paragraph("🔗 MATRICE DE CORRÉLATION", styles['EnteteSection']))
        story.append(Image("correlation_heatmap.png", width=500, height=300))

    # TABLE RÉCAPITULATIVE
    story.append(PageBreak())
    story.append(Paragraph("📋 TABLEAU RÉCAPITULATIF", styles['EnteteSection']))
    summary_data = [
        ["Nombre de bacs", df['bin_id'].nunique()],
        ["Types de déchets", ', '.join(df['trash_type'].unique())],
        ["Remplissage moyen (%)", round(df['trash_level'].mean(), 2)],
        ["Niveau moyen de gaz", round(df['gaz_level'].mean(), 2)],
        ["Température moyenne (°C)", round(df['temperature'].mean(), 2)]
    ]
    table = Table(summary_data, colWidths=[220, 300])
    table.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, 0), colors.HexColor('#2E86C1')),
        ('TEXTCOLOR', (0, 0), (-1, 0), colors.whitesmoke),
        ('ALIGN', (0, 0), (-1, -1), 'LEFT'),
        ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
        ('FONTSIZE', (0, 0), (-1, -1), 10),
        ('BOTTOMPADDING', (0, 0), (-1, 0), 12),
        ('BACKGROUND', (0, 1), (-1, -1), colors.whitesmoke),
        ('GRID', (0, 0), (-1, -1), 0.5, colors.grey)
    ]))
    story.append(table)

    # TABLE CRITIQUE
    critical_table = table_bacs_critiques(df)
    if critical_table:
        story.append(PageBreak())
        story.append(Paragraph("🚨 BACS EN SITUATION CRITIQUE", styles['EnteteSection']))
        story.append(critical_table)

    # NLP SUMMARY
    story.append(PageBreak())
    story.append(Paragraph("🧠 ANALYSE AVANCÉE PAR NLP", styles['EnteteSection']))
    story.append(Paragraph(generate_nlp_summary(df), styles['TexteCorps']))

    # SIGNATURE
    story.append(PageBreak())
    story.append(Spacer(1, 100))
    story.append(Paragraph("Fait à Beni Mellal, le " + datetime.now().strftime("%d/%m/%Y"), styles['TexteCorps']))
    story.append(Spacer(1, 30))
    story.append(Paragraph("<b>Signature :</b>", styles['TexteCorps']))
    story.append(Spacer(1, 50))
    story.append(Paragraph("<b>Le Directeur du Département IT</b>", styles['TexteCorps']))

    doc.build(story)
    print(f"📄 Rapport PDF généré : {filename}")

def generate_rapport_form_data(data, filename="statics/rapport_final_fr.pdf"):
    if not data:
        print("❗ Aucune donnée disponible pour générer le rapport.")
    else:
        df = load_and_clean_data(data)
        plot_distributions(df)
        plot_time_analysis(df)
        plot_correlation_heatmap(df)
        export_pdf_report(df, filename)
    # Cleanup generated images
    for file in ["rapport_analytique.png", "analyse_temporelle.png", "correlation_heatmap.png"]:
        if os.path.exists(file):
            os.remove(file)
            print(f"🗑️ Fichier supprimé : {file}")

