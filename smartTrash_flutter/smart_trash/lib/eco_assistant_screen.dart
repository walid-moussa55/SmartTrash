import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math' as math;
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'package:naqi_ai/app_theme.dart';
import 'package:naqi_ai/app_settings.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

enum ChatLanguage { english, french, arabic, darija }

class LanguageConfig {
  final String code;
  final String name;
  final String flag;
  final String speechLocale;
  final String systemPrompt;
  final String greeting;
  final String listeningHint;
  final String inputHint;
  final String errorServerNotConfigured;
  final String errorNoResponse;
  final String errorConnection;
  final TextDirection textDirection;

  const LanguageConfig({
    required this.code,
    required this.name,
    required this.flag,
    required this.speechLocale,
    required this.systemPrompt,
    required this.greeting,
    required this.listeningHint,
    required this.inputHint,
    required this.errorServerNotConfigured,
    required this.errorNoResponse,
    required this.errorConnection,
    this.textDirection = TextDirection.ltr,
  });
}

final Map<ChatLanguage, LanguageConfig> languageConfigs = {
  ChatLanguage.english: const LanguageConfig(
    code: 'en',
    name: 'English',
    flag: '🇬🇧',
    speechLocale: 'en_US',
    systemPrompt: """You are the Eco-Assistant of SmartBin IoT / NaqiAI, developed for Khouribga, Morocco.

ROLE: Answer questions about SmartBin IoT system, waste management, and recycling using ONLY the knowledge base provided.

SMARTBIN FACTS:
• IoT sensors: HC-SR04 ultrasonic (fill level), MQ-x gas detector, DHT11 (temp/humidity), load cell (weight), GPS
• ESP32 microcontroller with auto-opening lid via servo motor
• App levels: Admin (dashboard, analytics), Workers (optimized routes), Citizens (bin locations)
• AI: LSTM (fill prediction), DenseNet201 (waste classification), NLP (report generation)
• Route optimization: Dijkstra algorithm
• 6 zones in Khouribga: Centre-ville, Hay El Qods, Hay El Massira, Zone Industrielle, Hay Salam, Zone Universitaire

RESPONSE STYLE:
• Be concise (2-4 sentences max)
• Use emojis sparingly (1-2 per response)
• Give specific numbers/facts from knowledge base
• If info not in knowledge base, say "I don't have that specific information"

EXAMPLE:
User: "How many smart bins in the city center?"
Assistant: "The city center (Zone 1) has 35 smart bins! 🗑️ This zone has the highest density due to commercial activity, with collection twice daily at 6AM and 6PM."

DO NOT answer questions unrelated to SmartBin/waste/recycling.""",
    greeting: "Hello! 🌿 I'm your SmartBin Eco-Assistant. "
        "Ask me about waste sorting, the SmartBin system, or tap the mic to talk!",
    listeningHint: "🎤 I'm listening...",
    inputHint: "Ask about SmartBin...",
    errorServerNotConfigured: "Error: Server URL not configured.",
    errorNoResponse: "Sorry, I couldn't formulate a response.",
    errorConnection: "Connection refused. Make sure the NaqiAI server is running.",
  ),
  ChatLanguage.french: const LanguageConfig(
    code: 'fr',
    name: 'Français',
    flag: '🇫🇷',
    speechLocale: 'fr_FR',
    systemPrompt: """Tu es l'Eco-Assistant de SmartBin IoT / NaqiAI, développé pour Khouribga, Maroc.

RÔLE : Répondre aux questions sur SmartBin IoT, gestion des déchets et recyclage en utilisant UNIQUEMENT la base de connaissances.

FAITS SMARTBIN :
• Capteurs IoT : HC-SR04 ultrason (niveau), MQ-x gaz, DHT11 (temp/humidité), cellule de charge (poids), GPS
• Microcontrôleur ESP32 avec couvercle auto-ouvrant via servomoteur
• Niveaux app : Admin (tableau de bord), Workers (itinéraires optimisés), Citoyens (localisation poubelles)
• IA : LSTM (prédiction remplissage), DenseNet201 (classification déchets), NLP (génération rapports)
• Optimisation routes : algorithme Dijkstra
• 6 zones à Khouribga : Centre-ville, Hay El Qods, Hay El Massira, Zone Industrielle, Hay Salam, Zone Universitaire

STYLE DE RÉPONSE :
• Sois concis (2-4 phrases max)
• Utilise des emojis avec modération (1-2 par réponse)
• Donne des chiffres/faits précis de la base de connaissances
• Si info absente, dis "Je n'ai pas cette information spécifique"

EXEMPLE :
User: "Combien de poubelles au centre-ville ?"
Assistant: "Le centre-ville (Zone 1) compte 35 poubelles intelligentes ! 🗑️ C'est la zone la plus dense avec collecte 2 fois par jour à 6h et 18h."

NE RÉPONDS PAS aux questions sans rapport avec SmartBin/déchets/recyclage.""",
    greeting: "Bonjour ! 🌿 Je suis l'Eco-Assistant SmartBin. "
        "Demandez-moi comment trier vos déchets ou des infos sur SmartBin !",
    listeningHint: "🎤 Je vous écoute...",
    inputHint: "Question sur SmartBin...",
    errorServerNotConfigured: "Erreur : URL du serveur non configurée.",
    errorNoResponse: "Désolé, je n'ai pas pu formuler de réponse.",
    errorConnection: "Connexion refusée. Assurez-vous que le serveur NaqiAI est lancé.",
  ),
  ChatLanguage.arabic: const LanguageConfig(
    code: 'ar',
    name: 'العربية',
    flag: '🇸🇦',
    speechLocale: 'ar_SA',
    textDirection: TextDirection.rtl,
    systemPrompt: """أنت المساعد البيئي لنظام SmartBin IoT / NaqiAI، المطوّر لمدينة خريبكة، المغرب.

الدور: أجب على الأسئلة المتعلقة بنظام SmartBin IoT وإدارة النفايات وإعادة التدوير باستخدام قاعدة المعرفة المقدمة فقط.

معلومات SmartBin:
• المستشعرات: HC-SR04 فوق صوتي (مستوى الامتلاء)، كاشف غاز MQ-x، DHT11 (الحرارة/الرطوبة)، خلية وزن، GPS
• متحكم ESP32 مع غطاء يفتح تلقائياً بواسطة محرك سيرفو
• مستويات التطبيق: المسؤول (لوحة التحكم)، العمال (المسارات المحسّنة)، المواطنون (مواقع الحاويات)
• الذكاء الاصطناعي: LSTM (توقع الامتلاء)، DenseNet201 (تصنيف النفايات)، NLP (إنشاء التقارير)
• تحسين المسارات: خوارزمية Dijkstra
• 6 مناطق في خريبكة: وسط المدينة، حي القدس، حي المسيرة، المنطقة الصناعية، حي السلام، المنطقة الجامعية

أسلوب الإجابة:
• كن موجزاً (2-4 جمل كحد أقصى)
• استخدم الرموز التعبيرية باعتدال (1-2 لكل إجابة)
• أعطِ أرقاماً وحقائق دقيقة من قاعدة المعرفة
• إذا لم تكن المعلومة موجودة، قل "ليس لديّ هذه المعلومة المحددة"

مثال:
المستخدم: "كم عدد الحاويات الذكية في وسط المدينة؟"
المساعد: "يوجد في وسط المدينة (المنطقة 1) عدد 35 حاوية ذكية! 🗑️ هذه المنطقة الأكثر كثافة ويتم الجمع مرتين يومياً في الساعة 6 صباحاً و6 مساءً."

مثال آخر:
المستخدم: "ما هي المستشعرات المستخدمة؟"
المساعد: "تحتوي الحاوية الذكية على عدة مستشعرات 📡: مستشعر فوق صوتي HC-SR04 لقياس مستوى الامتلاء، كاشف غاز MQ-x للغازات الخطرة، DHT11 للحرارة والرطوبة، وخلية وزن لقياس كتلة النفايات."

لا تُجب على أسئلة لا علاقة لها بـ SmartBin أو النفايات أو إعادة التدوير.""",
    greeting: "مرحباً! 🌿 أنا المساعد البيئي SmartBin. "
        "اسألني عن فرز النفايات أو نظام SmartBin!",
    listeningHint: "🎤 أنا أستمع...",
    inputHint: "اسأل عن SmartBin...",
    errorServerNotConfigured: "خطأ: لم يتم تكوين عنوان الخادم.",
    errorNoResponse: "عذراً، لم أتمكن من صياغة رد.",
    errorConnection: "تم رفض الاتصال. تأكد من تشغيل خادم NaqiAI.",
  ),
  ChatLanguage.darija: const LanguageConfig(
    code: 'darija',
    name: 'Darija',
    flag: '🇲🇦',
    speechLocale: 'ar_MA',
    systemPrompt: """Nta l'Eco-Assistant dyal SmartBin IoT / NaqiAI, li tdar l mdinet Khouribga, lMghrib.

DORK: Jawb 3la les questions dyal SmartBin IoT, gestion dyal zbel w recyclage. Khdem GHIR l'infos men base de connaissances.

MA3LOUMAT SMARTBIN:
• Capteurs: HC-SR04 ultrason (niveau), MQ-x gaz, DHT11 (s5ana/rtoba), cellule de poids, GPS
• ESP32 m3a couvercle kay7ell bou7dou b servomoteur
• Niveaux dyal l'app: Admin (tableau de bord), Workers (routes optimisées), Citoyens (localisation poubelles)
• IA: LSTM (prédiction remplissage), DenseNet201 (classification zbel), NLP (génération rapports)
• Optimisation routes: algorithme Dijkstra
• 6 zones f Khouribga: Centre-ville (35 poubelle), Hay El Qods (22), Hay El Massira (18), Zone Industrielle (15), Hay Salam (12), Zone Universitaire (8)

KIFACH TJAWB:
• Kon mokhtssar (2-4 phrases max)
• Dir emojis chwiya (1-2 f kol jawab)
• 3ti chi9am w faits précis men base de connaissances
• Ila ma3ndk l'info, gol "Ma3ndich had l'info"

DARIJA = Moroccan dialect, maktoba b lettres latines (franco-arabe). Khdem kalimaat darija 7a9i9iya:
• zbel = déchets/ordures
• poubelle = sndou9/tanka
• kay7ell = s'ouvre
• s5ana = température/chaleur
• rtoba = humidité
• nqi = propre
• khawi = vide
• 3amr = plein
• jma3 = collecter

EXEMPLES DYAL JAWABAT MEZYANIN:

User: "Ch7al men poubelle f centre-ville?"
Assistant: "F centre-ville (Zone 1) kaynin 35 poubelle intelligente! 🗑️ Had zone fiha bzaf dyal nass, w kayjm3ou zbel jouj mrrat f nhar: 6 dyal sba7 w 6 dyal l3chiya."

User: "Chnou hiya les capteurs?"
Assistant: "Poubelle SmartBin fiha bzaf dyal capteurs 📡: HC-SR04 bach n3rfou wach 3amra wla khawya, capteur dyal gaz bach ndetectiwi gaz khatir, DHT11 l s5ana w rtoba, w capteur dyal lwezn."

User: "Kifach kaykhdm système?"
Assistant: "SmartBin kaykhdm b ESP32 li howa l'cerveau 🧠. Capteurs kayjm3ou data (niveau, gaz, s5ana...), w kaytssift l cloud. L'app katwerri kolchi l admin w workers, w Dijkstra kayoptimisa routes dyal camions."

User: "Chnou hiya IA li kayna?"
Assistant: "Kaynin 3 modèles dyal IA 🤖: LSTM li kayt-prédicti mta y3mr zbel, DenseNet201 li kayfrz type dyal zbel (plastique, verre...), w NLP li kaygénéri rapports automatiquement."

MA TRDDCH 3LA LES QUESTIONS LI MA3NDHOMCH 3ALA9A B SMARTBIN/ZBEL/RECYCLAGE.""",
    greeting: "Salam! 🌿 Ana l'Eco-Assistant dyal SmartBin. "
        "Swelni 3la tri dyal zbel wla système SmartBin!",
    listeningHint: "🎤 Kansmaa3 lik...",
    inputHint: "Swel 3la SmartBin...",
    errorServerNotConfigured: "Khata: URL dyal serveur makaynach.",
    errorNoResponse: "Smahli, ma9dertch njawbek.",
    errorConnection: "Connection refusée. T2akked belli serveur NaqiAI khdam.",
  ),
};

class ChatMessage {
  final String text;
  final bool isUser;
  final Key key;

  ChatMessage({required this.text, required this.isUser})
      : key = UniqueKey();
}

class EcoAssistantScreen extends StatefulWidget {
  const EcoAssistantScreen({super.key});

  @override
  State<EcoAssistantScreen> createState() => _EcoAssistantScreenState();
}

class _EcoAssistantScreenState extends State<EcoAssistantScreen> with TickerProviderStateMixin {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  final AppSettings _appSettings = AppSettings();

  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  bool _speechAvailable = false;
  bool _isAiTyping = false;

  final List<Map<String, String>> _chatHistory = [];

  // ── Palette NaqiAI Stricte ──
  static const Color _kBg       = Color(0xFFF5F3EE);
  static const Color _kSurface  = Color(0xFFFFFFFF);
  static const Color _kBorder   = Color(0xFFE2DDD5);
  static const Color _kPale     = Color(0xFFDCF0E0);
  static const Color _kLight    = Color(0xFF8EBF93);
  static const Color _kMid      = Color(0xFF5C8E60);
  static const Color _kPrimary  = Color(0xFF2A4A30);
  static const Color _kAlertPale = Color(0xFFF0E8DC);
  static const Color _kAlert    = Color(0xFFB86B2A);
  static const Color _kTextSec  = Color(0xFF7A8A7C);

  late AnimationController _pulseController;
  late AnimationController _dotsController;

  // Language selection
  ChatLanguage _selectedLanguage = ChatLanguage.french;
  LanguageConfig get _langConfig => languageConfigs[_selectedLanguage]!;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);
    _dotsController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat();
    _initSpeech();
    _initChat();
  }

  void _initSpeech() async {
    try {
      bool available = await _speech.initialize(
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            if (mounted && _isListening) {
              setState(() => _isListening = false);
              if (_textController.text.trim().isNotEmpty) {
                _sendMessage(_textController.text.trim());
              }
            }
          }
        },
        onError: (errorNotification) {
          debugPrint("Speech error: ${errorNotification.errorMsg}");
          if (mounted) setState(() => _isListening = false);
        },
      );
      if (mounted) setState(() => _speechAvailable = available);
    } catch (e) {
      debugPrint("Speech init error: $e");
    }
  }

  void _initChat() {
    _chatHistory.add({"role": "system", "content": _langConfig.systemPrompt});
    _addMessage(_langConfig.greeting, false);
  }

  void _changeLanguage(ChatLanguage newLanguage) {
    if (newLanguage == _selectedLanguage) return;
    
    setState(() {
      _selectedLanguage = newLanguage;
      _messages.clear();
      _chatHistory.clear();
    });
    _initChat();
  }

  void _showLanguageSelector() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.3),
      builder: (context) => Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.only(top: 80, left: 20, right: 20),
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 450,
              decoration: BoxDecoration(
                color: _kAlertPale,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: _kBorder, width: 1.5),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 30, offset: const Offset(0, 10))],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      'CHOISIR LA LANGUE',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: _kPrimary, letterSpacing: 1.5),
                    ),
                  ),
                  Divider(color: _kBorder.withOpacity(0.5), height: 1),
                  ...ChatLanguage.values.map((lang) {
                    final config = languageConfigs[lang]!;
                    final isSelected = lang == _selectedLanguage;
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                      leading: Text(config.flag, style: const TextStyle(fontSize: 24)),
                      title: Text(
                        config.name,
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                          color: isSelected ? _kPrimary : _kTextSec,
                          fontSize: 15,
                        ),
                      ),
                      trailing: isSelected ? Icon(Icons.check_circle_rounded, color: _kPrimary, size: 20) : null,
                      onTap: () {
                        Navigator.pop(context); // Disparaît automatiquement
                        _changeLanguage(lang);
                      },
                    );
                  }),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _addMessage(String text, bool isUser) {
    if (!mounted) return;
    setState(() {
      _messages.add(ChatMessage(text: text, isUser: isUser));
    });
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    _addMessage(text, true);
    _textController.clear();
    _chatHistory.add({"role": "user", "content": text});

    setState(() => _isAiTyping = true);

    try {
      final serverUrl = _appSettings.rotageServerUrl;
      if (serverUrl == null || serverUrl.isEmpty) {
        _addMessage(_langConfig.errorServerNotConfigured, false);
        return;
      }

      final response = await http.post(
        Uri.parse('$serverUrl/api/chat'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"messages": _chatHistory}),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        if (data.containsKey('reply')) {
          String aiResponse = data['reply'];
          _addMessage(aiResponse, false);
          _chatHistory.add({"role": "assistant", "content": aiResponse});
        } else {
          _addMessage(_langConfig.errorNoResponse, false);
        }
      } else {
        String errorMsg = "Error (Code ${response.statusCode}).";
        try {
          final Map<String, dynamic> errData = jsonDecode(utf8.decode(response.bodyBytes));
          if (errData.containsKey('detail')) errorMsg = "⚠️ ${errData['detail']}";
        } catch (_) {}
        _addMessage(errorMsg, false);
      }
    } catch (e) {
      _addMessage(_langConfig.errorConnection, false);
      debugPrint("Chat error: $e");
    } finally {
      if (mounted) setState(() => _isAiTyping = false);
    }
  }

  void _toggleListening() async {
    if (_isListening) {
      setState(() => _isListening = false);
      await _speech.stop();
      if (_textController.text.trim().isNotEmpty) {
        _sendMessage(_textController.text.trim());
      }
      return;
    }

    if (!kIsWeb) {
      var status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Permission micro refusée. Activez-la dans les paramètres.")),
          );
        }
        return;
      }
    }

    if (!_speechAvailable) _speechAvailable = await _speech.initialize();

    if (_speechAvailable) {
      setState(() => _isListening = true);
      _textController.clear();
      await _speech.listen(
        onResult: (val) {
          if (mounted) {
            setState(() => _textController.text = val.recognizedWords);
            if (val.finalResult && val.recognizedWords.trim().isNotEmpty) {
              setState(() => _isListening = false);
              _speech.stop();
              _sendMessage(val.recognizedWords.trim());
            }
          }
        },
        localeId: _langConfig.speechLocale,
        listenOptions: stt.SpeechListenOptions(listenMode: stt.ListenMode.dictation),
      );
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Reconnaissance vocale non disponible sur cet appareil.")),
        );
      }
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _pulseController.dispose();
    _dotsController.dispose();
    _speech.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool usePopup = kIsWeb && screenWidth > 700;

    Widget content = _buildMainUI();

    if (usePopup) {
      return Scaffold(
        backgroundColor: Colors.black.withOpacity(0.05),
        body: Center(
          child: Container(
            width: screenWidth * 0.9,
            constraints: const BoxConstraints(maxWidth: 1000),
            margin: const EdgeInsets.symmetric(vertical: 24),
            decoration: BoxDecoration(
              color: _kBg,
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 40, offset: const Offset(0, 15)),
              ],
              border: Border.all(color: _kBorder, width: 1),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(32),
              child: content,
            ),
          ),
        ),
      );
    }

    return content;
  }

  Widget _buildMainUI() {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [_kPrimary, _kMid],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: Row(
          children: [
            _buildLogo(),
            const SizedBox(width: 14),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Eco-Assistant', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.2)),
                Text('Intelligence Environnementale', style: TextStyle(fontSize: 10, color: Colors.white70, fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        ),
        actions: [
          _buildLanguageButton(),
        ],
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return _AnimatedChatBubble(
                  key: msg.key,
                  text: msg.text,
                  isUser: msg.isUser,
                );
              },
            ),
          ),
          if (_isAiTyping) _buildTypingIndicator(),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Icon(Icons.eco_rounded, color: Colors.white, size: 22),
          Positioned(
            right: -2, top: -2,
            child: Container(
              width: 8, height: 8,
              decoration: BoxDecoration(
                color: _kLight,
                shape: BoxShape.circle,
                border: Border.all(color: _kPrimary, width: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageButton() {
    return GestureDetector(
      onTap: _showLanguageSelector,
      child: Container(
        margin: const EdgeInsets.only(right: 16),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.15)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_langConfig.flag, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Text(
              _langConfig.name.toUpperCase(),
              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.expand_more_rounded, color: Colors.white70, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(left: 20, bottom: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: AnimatedBuilder(
          animation: _dotsController,
          builder: (context, _) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
                border: Border.all(color: _kBorder.withOpacity(0.5)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(3, (i) {
                  final phase = (_dotsController.value + i * 0.25) % 1.0;
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    child: Transform.translate(
                      offset: Offset(0, -4 * math.sin(phase * math.pi)),
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _kPrimary.withAlpha((120 + 135 * math.sin(phase * math.pi)).toInt()),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  );
                }),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: _kBg,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: _kBorder.withValues(alpha: 0.6)),
          boxShadow: [
            BoxShadow(color: _kTextSec.withValues(alpha: 0.1), blurRadius: 15, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            // Voice Input Button
            GestureDetector(
              onTap: _toggleListening,
              child: AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  final scale = _isListening ? 1.0 + 0.1 * math.sin(_pulseController.value * math.pi) : 1.0;
                  return Transform.scale(scale: scale, child: child);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: _isListening
                        ? const LinearGradient(colors: [_kAlert, Color(0xFFD94E2B)])
                        : null,
                    color: _isListening ? null : _kBg,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _isListening ? _kAlert : _kBorder,
                      width: 1.5,
                    ),
                    boxShadow: _isListening
                        ? [BoxShadow(color: _kAlert.withAlpha(60), blurRadius: 12, spreadRadius: 1)]
                        : [],
                  ),
                  child: Icon(
                    _isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                    color: _isListening ? Colors.white : _kPrimary,
                    size: 22,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Text Input
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: _kBg,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _textController,
                  textDirection: _langConfig.textDirection,
                  style: const TextStyle(fontSize: 15, color: _kPrimary, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    hintText: _isListening ? _langConfig.listeningHint : _langConfig.inputHint,
                    hintStyle: TextStyle(color: _kTextSec.withOpacity(0.5), fontSize: 14),
                    filled: true,
                    fillColor: _kBg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  onSubmitted: _sendMessage,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Send Button
            GestureDetector(
              onTap: () => _sendMessage(_textController.text),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _kPrimary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: _kPrimary.withAlpha(40), blurRadius: 8, offset: const Offset(0, 3)),
                  ],
                ),
                child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Animated chat bubble that slides in from left/right
class _AnimatedChatBubble extends StatefulWidget {
  final String text;
  final bool isUser;

  const _AnimatedChatBubble({
    required super.key,
    required this.text,
    required this.isUser,
  });

  @override
  State<_AnimatedChatBubble> createState() => _AnimatedChatBubbleState();
}

class _AnimatedChatBubbleState extends State<_AnimatedChatBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: Offset(widget.isUser ? 0.3 : -0.3, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _fadeAnimation = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Align(
          alignment: widget.isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: widget.isUser ? _EcoAssistantScreenState._kPrimary : Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(20),
                topRight: const Radius.circular(20),
                bottomLeft: widget.isUser ? const Radius.circular(20) : const Radius.circular(4),
                bottomRight: widget.isUser ? const Radius.circular(4) : const Radius.circular(20),
              ),
              border: widget.isUser ? null : Border.all(color: _EcoAssistantScreenState._kBorder.withOpacity(0.5)),
              boxShadow: [
                BoxShadow(
                  color: (widget.isUser ? _EcoAssistantScreenState._kPrimary : Colors.black).withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
            child: Text(
              widget.text,
              style: TextStyle(
                color: widget.isUser ? Colors.white : _EcoAssistantScreenState._kPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
