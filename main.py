from fastapi import FastAPI, UploadFile, File
from fastapi.middleware.cors import CORSMiddleware
import os
import shutil
import uuid
from PyPDF2 import PdfReader
import json
import re
import pandas as pd
from groq import Groq

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
                {
                    "role": "system",
                    "content": "Responde preguntas usando el contenido del documento"
                },
                {
                    "role": "user",
                    "content": f"{contenido}\n\nPregunta: {query}"
                }
            ]
        )
        print("📩 PREGUNTA:", pregunta)

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
    global textos

    try:
        if not textos:
            return {"data": [], "resumen": []}

        contenido = textos[0]

        data = []

        # -----------------------------
        # 🤖 IA (segura)
        # -----------------------------
        try:
            respuesta = client.chat.completions.create(
                model="llama-3.1-8b-instant",
                messages=[
                    {
                        "role": "system",
                        "content": """
Extrae TODOS los registros del documento.

Devuelve SOLO JSON válido:

[
 {"cliente": "", "monto": 0, "fecha": ""}
]

Sin texto adicional.
Nunca devuelvas explicación.
"""
                    },
                    {"role": "user", "content": contenido}
                ]
            )

            texto = respuesta.choices[0].message.content.strip()
            print("🧠 IA RAW:", texto)

            match = re.search(r"\[.*\]", texto, re.DOTALL)

            if match:
                data = json.loads(match.group(0))
            else:
                data = []

        except Exception as e:
            print("⚠️ IA FALLÓ:", e)
            data = []

        # -----------------------------
        # 🧼 LIMPIEZA
        # -----------------------------
        data_limpia = []

        for item in data:
            if not isinstance(item, dict):
                continue

            cliente = item.get("cliente") or "Desconocido"
            monto = item.get("monto") or 0
            fecha = item.get("fecha") or "N/A"

            try:
                monto = float(monto)
            except:
                monto = 0

            data_limpia.append({
                "cliente": cliente,
                "monto": monto,
                "fecha": fecha
            })

        # -----------------------------
        # 🔥 FALLBACK SI IA FALLA
        # -----------------------------
        if not data_limpia:
            lineas = contenido.split("\n")

            for i, linea in enumerate(lineas):

                match_monto = re.search(r'\$?\s?\d{4,}(?:,\d{3})*(?:\.\d+)?', linea)

                if match_monto:
                    valor = float(re.sub(r"[^\d.]", "", match_monto.group()))

                    if 2000 <= valor <= 2035:
                        continue

                    cliente = "Desconocido"

                    for j in range(max(0, i-3), i):
                        posible = lineas[j].strip()
                        if posible and not any(c.isdigit() for c in posible):
                            cliente = posible
                            break

                    if cliente.lower() in ["monto", "fecha", "cliente"]:
                        continue

                    fecha = "N/A"
                    match_fecha = re.search(r'\d{1,2}[/\-]\d{1,2}[/\-]\d{2,4}', linea)

                    if not match_fecha:
                        for j in range(i, min(i+3, len(lineas))):
                            match_fecha = re.search(r'\d{1,2}[/\-]\d{1,2}[/\-]\d{2,4}', lineas[j])
                            if match_fecha:
                                break

                    if match_fecha:
                        fecha = match_fecha.group()
                        print("📄 TEXTO EXTRAÍDO:", texto[:500])

                    data_limpia.append({
                        "cliente": cliente,
                        "monto": valor,
                        "fecha": fecha
                    })

        # -----------------------------
        # 🔁 QUITAR DUPLICADOS
        # -----------------------------
        data_unica = []
        vistos = set()

        for item in data_limpia:
            clave = (item["cliente"], item["monto"], item["fecha"])

            if clave not in vistos:
                vistos.add(clave)
                data_unica.append(item)

        # -----------------------------
        # 📊 AGRUPAR
        # -----------------------------
        resumen = {}

        for item in data_unica:
            cliente = item["cliente"]
            monto = item["monto"]

            if cliente not in resumen:
                resumen[cliente] = 0

            resumen[cliente] += monto

        resumen_lista = [
            {"cliente": k, "total": v}
            for k, v in resumen.items()
        ]

        # -----------------------------
        # 📁 EXPORTAR EXCEL
        # -----------------------------
        try:
            df = pd.DataFrame(data_unica)
            df.to_excel("reporte.xlsx", index=False)
        except Exception as e:
            print("⚠️ ERROR EXCEL:", e)

        # -----------------------------
        # 🚀 RESPUESTA FINAL
        # -----------------------------
        return {
            "data": data_unica,
            "resumen": resumen_lista
        }

    except Exception as e:
        print("🔥 ERROR ANALISIS:", e)
        return {
            "data": [],
            "resumen": []
        }