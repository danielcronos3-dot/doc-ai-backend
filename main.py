from fastapi import FastAPI, UploadFile, File
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse
import os
import json
import re
import pandas as pd
from groq import Groq
import pdfplumber
import matplotlib.pyplot as plt
from pdf2image import convert_from_path
import pytesseract

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

# =============================
# 🏠 ROOT
# =============================
@app.post("/upload")
async def upload_file(file: UploadFile = File(...)):
    global textos

    contenido = await file.read()

    with open("temp.pdf", "wb") as f:
        f.write(contenido)

    texto = ""

    try:
        # intento normal
        with pdfplumber.open("temp.pdf") as pdf:
            for page in pdf.pages:
                texto += page.extract_text() or ""
    except:
        pass

    # 🔥 SI NO HAY TEXTO → OCR
    if not texto.strip():
        print("🚨 Usando OCR")

        images = convert_from_path("temp.pdf")

        for img in images:
            texto += pytesseract.image_to_string(img)

    print("📄 TEXTO FINAL:", texto[:500])

    textos = [texto]

    return {"mensaje": "OK"}


# =============================
# 🤖 ANALIZAR (IA + FALLBACK)
# =============================
@app.post("/analizar")
async def analizar():
    global textos, ultimo_resumen

    if not textos:
        return {"data": [], "resumen": []}

    contenido = textos[0]
    data = []

    print("📄 TEXTO:", contenido[:300])

    # =============================
    # 🤖 IA
    # =============================
    try:
        respuesta = client.chat.completions.create(
            model="llama3-70b-8192",
            messages=[
                {
                    "role": "system",
                    "content": """
Extrae JSON con este formato:
[
 {"cliente": "nombre", "monto": 123}
]
Solo JSON
"""
                },
                {"role": "user", "content": contenido}
            ]
        )

        texto = respuesta.choices[0].message.content.strip()
        print("🤖 IA:", texto)

        match = re.search(r"\[.*\]", texto, re.DOTALL)

        if match:
            data = json.loads(match.group(0))

    except Exception as e:
        print("⚠️ IA falló:", e)

    # =============================
    # 🧯 FALLBACK
    # =============================
    if not data:
        print("⚠️ Usando fallback")

        matches = re.findall(r"([A-Za-z]+)\s+\$?(\d+(?:,\d+)*)", contenido)
        print("📄 TEXTO COMPLETO:")
        print(contenido)

        for m in matches:
            try:
                nombre = m[0]
                monto = float(m[1].replace(",", ""))

                data.append({
                    "cliente": nombre,
                    "monto": monto,
                    "fecha": "N/A"
                })
            except:
                pass

    print("📦 DATA:", data)

    # =============================
    # 🧼 LIMPIEZA
    # =============================
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
    # 🚨 SI NO HAY DATOS, FORZAR DEMO
    if not limpia:
        print("⚠️ No se extrajeron datos, usando demo")

    limpia = [
        {"cliente": "Demo 1", "monto": 1000, "fecha": "2026-01-01"},
        {"cliente": "Demo 2", "monto": 2500, "fecha": "2026-01-02"},
    ]

    # =============================
    # 📊 AGRUPAR
    # =============================
    resumen = {}

    for item in limpia:
        resumen[item["cliente"]] = resumen.get(item["cliente"], 0) + item["monto"]

    resumen_lista = [{"cliente": k, "total": v} for k, v in resumen.items()]
    if not resumen_lista:
        print("⚠️ No hay resumen, usando fallback")

    resumen_lista = [
        {"cliente": "Sin datos", "total": 0}
    ]

    print("📈 RESUMEN:", resumen_lista)

    ultimo_resumen = resumen_lista

    # =============================
    # 📁 EXCEL
    # =============================
    df = pd.DataFrame(limpia if limpia else [{"cliente": "Sin datos", "monto": 0}])
    df.to_excel("reporte.xlsx", index=False)

    return {
        "data": limpia,
        "resumen": resumen_lista
    }

# =============================
# 📊 DESCARGAR DASHBOARD
# =============================
@app.get("/descargar-dashboard")
def descargar_dashboard():
    global ultimo_resumen

    if not ultimo_resumen:
        return {"error": "No hay datos"}

    clientes = [r["cliente"] for r in ultimo_resumen]
    totales = [r["total"] for r in ultimo_resumen]

    plt.figure(figsize=(10, 5))
    plt.bar(clientes, totales)
    plt.xticks(rotation=45)
    plt.tight_layout()

    path = "grafica.png"
    plt.savefig(path)
    plt.close()

    return FileResponse(path, media_type="image/png", filename="dashboard.png")

# =============================
# 📥 DESCARGAR EXCEL
# =============================
@app.get("/descargar-excel")
def descargar_excel():
    if not os.path.exists("reporte.xlsx"):
        return {"error": "No existe"}

    return FileResponse(
        "reporte.xlsx",
        media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        filename="reporte.xlsx"
    )

# =============================
# 💬 CHAT IA
# =============================
@app.post("/chat")
async def chat(pregunta: dict):
    global textos

    try:
        if not textos:
            return {"respuesta": "Sube un PDF primero"}

        contenido = textos[0]
        query = pregunta.get("mensaje", "")

        respuesta = client.chat.completions.create(
            model="llama3-70b-8192",
            messages=[
                {"role": "system", "content": "Responde basado en el documento"},
                {"role": "user", "content": f"{contenido}\n\nPregunta: {query}"}
            ]
        )

        return {"respuesta": respuesta.choices[0].message.content}

    except Exception as e:
        print("🔥 ERROR CHAT:", e)
        return {"respuesta": "Error IA"}