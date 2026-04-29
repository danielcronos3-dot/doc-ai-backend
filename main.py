from fastapi import FastAPI, UploadFile, File
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse
import os
import shutil
import uuid
from PyPDF2 import PdfReader
import json
import re
import pandas as pd
from groq import Groq
import matplotlib.pyplot as plt

textos = []
ultimo_resumen = []
app = FastAPI()

# 🌐 CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 🔑 IA
client = Groq(api_key=os.getenv("GROQ_API_KEY"))

# 🧠 memoria
textos = []
ultimo_resumen = []

# -----------------------------
# 📥 DESCARGAR EXCEL
# -----------------------------
@app.get("/descargar-excel")
def descargar_excel():
    if not os.path.exists("reporte.xlsx"):
        return {"error": "Archivo no generado aún"}

    return FileResponse(
        "reporte.xlsx",
        media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        filename="reporte.xlsx"
    )

# -----------------------------
# 📊 DESCARGAR DASHBOARD
# -----------------------------
@app.get("/descargar-dashboard")
def descargar_dashboard():
    global ultimo_resumen

    if not ultimo_resumen:
        return {"error": "No hay datos"}

    clientes = [r["cliente"] for r in ultimo_resumen]
    totales = [r["total"] for r in ultimo_resumen]

    plt.figure(figsize=(8, 4))
    plt.bar(clientes, totales)
    plt.xticks(rotation=45)

    path = "grafica.png"
    plt.savefig(path, bbox_inches="tight")
    plt.close()

    return FileResponse(
        path,
        media_type="image/png",
        filename="dashboard.png"
    )

# -----------------------------
# 📄 UPLOAD
# -----------------------------
@app.post("/upload")
async def upload_file(file: UploadFile = File(...)):
    global textos

    try:
        file_path = f"temp_{uuid.uuid4()}.pdf"

        with open(file_path, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)

        reader = PdfReader(file_path)

        texto = ""
        for page in reader.pages:
            contenido = page.extract_text()
            if contenido:
                texto += contenido + "\n"

        os.remove(file_path)

        if not texto.strip():
            return {"mensaje": "PDF vacío"}

        textos = [texto[:4000]]

        return {"mensaje": "OK"}

    except Exception as e:
        print("🔥 ERROR UPLOAD:", e)
        return {"mensaje": "ERROR"}

# -----------------------------
# 💬 CHAT IA
# -----------------------------
@app.post("/chat")
async def chat(pregunta: dict):
    global textos

    try:
        if not textos:
            return {"respuesta": "Sube un PDF primero"}

        query = pregunta.get("mensaje", "")
        contenido = textos[0]

        respuesta = client.chat.completions.create(
            model="llama-3.1-8b-instant",
            messages=[
                {"role": "system", "content": "Responde usando el documento"},
                {"role": "user", "content": f"{contenido}\n\nPregunta: {query}"}
            ]
        )

        return {
            "respuesta": respuesta.choices[0].message.content
        }

    except Exception as e:
        print("❌ ERROR CHAT:", e)
        return {"respuesta": "Error IA"}

# -----------------------------
# 🤖 ANALIZAR
# -----------------------------
@app.post("/analizar")
async def analizar():
    global textos, ultimo_resumen

    try:
        if not textos:
            return {"data": [], "resumen": []}

        contenido = textos[0]

        data = []

        # 🤖 IA
        try:
            respuesta = client.chat.completions.create(
                model="llama-3.1-8b-instant",
                messages=[
                    {
                        "role": "system",
                        "content": """
Devuelve SOLO JSON válido:

[{"cliente": "", "monto": 0, "fecha": ""}]
"""
                    },
                    {"role": "user", "content": contenido}
                ]
            )

            texto = respuesta.choices[0].message.content.strip()
            match = re.search(r"\[.*\]", texto, re.DOTALL)

            if match:
                data = json.loads(match.group(0))

        except Exception as e:
            print("⚠️ IA FALLÓ:", e)

        # 🧼 LIMPIEZA
        limpia = []
        for item in data:
            try:
                limpia.append({
                    "cliente": item.get("cliente", "Desconocido"),
                    "monto": float(item.get("monto", 0)),
                    "fecha": item.get("fecha", "N/A")
                })
            except:
                pass

        # 📊 AGRUPAR
        resumen = {}
        for item in limpia:
            resumen[item["cliente"]] = resumen.get(item["cliente"], 0) + item["monto"]

        resumen_lista = [{"cliente": k, "total": v} for k, v in resumen.items()]
        ultimo_resumen = resumen_lista

        # 📁 EXCEL
        df = pd.DataFrame(limpia)
        df.to_excel("reporte.xlsx", index=False)

        return {
            "data": limpia,
            "resumen": resumen_lista
        }

    except Exception as e:
        print("🔥 ERROR ANALISIS:", e)
        return {"data": [], "resumen": []}