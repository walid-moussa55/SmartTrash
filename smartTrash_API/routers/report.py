from fastapi import APIRouter
import os
from fastapi import HTTPException
from fastapi.responses import PlainTextResponse, Response, JSONResponse
import pandas as pd
from reports.anomalie_comment import AnomalieComment
from reports.paterns_usage import generate_patern_usage
from reports.rapprot_generator import generate_rapport_form_data
from utils.constants import REPORT_PATH
from others.database import MongoDB 

router = APIRouter()
db_mongo = MongoDB()


@router.post("/generate-report")
async def generate_report():
    try:
        # 1. Generate the report (your existing logic)
        db_data = db_mongo.get_all_data() # Replace with your actual data fetching
        generate_rapport_form_data(db_data, filename=REPORT_PATH) # Generate the PDF and save it

        # 2. Read the generated PDF file's content
        if not os.path.exists(REPORT_PATH):
            raise HTTPException(status_code=500, detail="Report file was not generated at the specified path.")

        # Option B: Reading bytes directly and returning (more flexible)
        with open(REPORT_PATH, "rb") as f:
            pdf_content = f.read()

        return Response(
            content=pdf_content,
            media_type="application/pdf",
            headers={"Content-Disposition": "attachment; filename=SmartTrash_Rapport.pdf"}
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Erreur lors de la génération du rapport: {e}")

from fastapi.responses import FileResponse

@router.get("/generated-report.pdf")
async def serve_pdf():
    if not os.path.exists(REPORT_PATH):
        raise HTTPException(status_code=404, detail="Report file not found.")
    return FileResponse(
        path=REPORT_PATH,
        media_type="application/pdf",
        filename="SmartTrash_Rapport.pdf"
    )

@router.get("/anomaly-recommendations")
async def get_anomaly_recommendations():
    try:
        data_raw = db_mongo.get_all_data()
        data = pd.DataFrame(data_raw)
        anomalie_comment = AnomalieComment(data)
        anomalie_comment.train_model()
        recommendations = anomalie_comment.generate_recommendation()
        return JSONResponse(content={"recommendations": recommendations})
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Erreur lors de la génération des recommandations : {e}")
    
@router.get("/get-patterns-analysis-markdown", response_class=PlainTextResponse)
async def get_markdown_report():
    """
    Serves a Markdown file from the server.
    """
    data = db_mongo.get_all_data()
    MARKDOWN_FILE_PATH = generate_patern_usage(data)

    if not os.path.exists(MARKDOWN_FILE_PATH):
        raise HTTPException(status_code=404, detail=f"Markdown file not found at {MARKDOWN_FILE_PATH}")
    
    try:
        with open(MARKDOWN_FILE_PATH, "r", encoding="utf-8") as f:
            content = f.read()
        return content
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error reading Markdown file: {e}")
