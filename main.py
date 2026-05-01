from fastapi import FastAPI, UploadFile, File
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse
import os
import re
import json
import pandas as pd
import matplotlib.pyplot as plt
from groq import Groq
import time
import pdfplumber
import uuid
import base64
import mimetypes
from typing import List
from dotenv import load_dotenv
load_dotenv()


# =============================
# 🔥 LOGGER PRO
# =============================
def log(tag, msg):
    print(f"[{tag}] {msg}")

def log_request(endpoint):
    rid = str(uuid.uuid4())[:8]
    log("REQ", f"{endpoint} | id={rid}")
    return rid

# =============================
# OCR opcional
# =============================
try:
    from pdf2image import convert_from_path
    import pytesseract
    OCR_DISPONIBLE = True
except:
    print("OCR no disponible")
    OCR_DISPONIBLE = False

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

textos = []
ultimo_resumen = []

# =============================
# ROOT
# =============================
@app.get("/")
def root():
    return {"status": "ok"}

def extraer_texto_pdf(path):
    texto = ""

    try:
        with pdfplumber.open(path) as pdf:
            for page in pdf.pages:
                texto += page.extract_text() or ""
    except Exception as e:
        print(f"pdfplumber error: {e}")

    if not texto.strip() and OCR_DISPONIBLE:
        try:
            images = convert_from_path(path)
            for img in images:
                texto += pytesseract.image_to_string(img)
        except Exception as e:
            print(f"OCR PDF error: {e}")

    return texto


def extraer_texto_imagen(path):
    api_key = os.getenv("GROQ_API_KEY")

    if not api_key:
        return ""

    try:
        mime_type, _ = mimetypes.guess_type(path)
        if not mime_type:
            mime_type = "image/jpeg"

        with open(path, "rb") as image_file:
            base64_image = base64.b64encode(image_file.read()).decode("utf-8")

        client = Groq(api_key=api_key)

        resp = client.chat.completions.create(
            model="meta-llama/llama-4-scout-17b-16e-instruct",
            messages=[
                {
                    "role": "user",
                    "content": [
                        {
                            "type": "text",
                            "text": """
Lee esta imagen y extrae todo el texto visible.
Si hay clientes, montos, fechas, facturas o tablas, respétalos.
Devuelve únicamente texto plano, sin explicación.
"""
                        },
                        {
                            "type": "image_url",
                            "image_url": {
                                "url": f"data:{mime_type};base64,{base64_image}"
                            }
                        }
                    ]
                }
            ],
            temperature=0,
            max_completion_tokens=2048,
        )

        return resp.choices[0].message.content.strip()

    except Exception as e:
        print(f"Vision imagen error: {e}")
        return ""



def extraer_texto_excel(path):
    try:
        hojas = pd.read_excel(path, sheet_name=None)
        texto = ""

        for nombre_hoja, df in hojas.items():
            texto += f"\n\nHOJA: {nombre_hoja}\n"
            texto += df.to_string(index=False)

        return texto
    except Exception as e:
        print(f"Excel error: {e}")
        return ""


def extraer_texto_simple(path):
    try:
        with open(path, "r", encoding="utf-8", errors="ignore") as f:
            return f.read()
    except Exception as e:
        print(f"Texto simple error: {e}")
        return ""


# =============================
# UPLOAD
# =============================
@app.post("/upload")
async def upload(files: List[UploadFile] = File(...)):
    global textos

    rid = log_request("UPLOAD")
    start = time.time()

    try:
        textos = []
        previews = []

        for file in files:
            contenido = await file.read()
            filename = file.filename or "archivo"
            ext = os.path.splitext(filename.lower())[1]

            safe_name = f"temp_{uuid.uuid4().hex}{ext}"

            with open(safe_name, "wb") as f:
                f.write(contenido)

            log(rid, f"📦 {filename}: {len(contenido)} bytes")

            texto = ""

            if ext == ".pdf":
                texto = extraer_texto_pdf(safe_name)

            elif ext in [".png", ".jpg", ".jpeg", ".webp", ".bmp"]:
                texto = extraer_texto_imagen(safe_name)

            elif ext in [".xlsx", ".xls", ".csv"]:
                if ext == ".csv":
                    texto = extraer_texto_simple(safe_name)
                else:
                    texto = extraer_texto_excel(safe_name)

            elif ext in [".sql", ".txt", ".json", ".xml", ".html", ".md"]:
                texto = extraer_texto_simple(safe_name)

            else:
                texto = extraer_texto_simple(safe_name)

            texto_con_nombre = f"\n\n===== ARCHIVO: {filename} =====\n{texto}"
            textos.append(texto_con_nombre)

            previews.append({
                "archivo": filename,
                "texto_len": len(texto),
                "preview": texto[:200]
            })

            try:
                os.remove(safe_name)
            except:
                pass

        log(rid, f"📄 archivos procesados: {len(textos)}")
        log(rid, f"⏱ {round(time.time()-start, 2)}s")

        return {
            "mensaje": "OK",
            "archivos": len(textos),
            "previews": previews
        }

    except Exception as e:
        log(rid, f"🔥 ERROR UPLOAD: {e}")
        return {"mensaje": "ERROR", "error": str(e)}

# =============================
# ANALIZAR
# =============================
@app.post("/analizar")
async def analizar():
    global textos, ultimo_resumen

    rid = log_request("ANALIZAR")
    start = time.time()

    try:
        modo_test = False  # CAMBIA A True PARA DEBUG

        data = []

        # 🧪 TEST
        if modo_test:
            log(rid, "🧪 MODO TEST")
            data = [
                {"cliente": "Carlos", "monto": 1200, "fecha": "2026"},
                {"cliente": "Ana", "monto": 2500, "fecha": "2026"},
                {"cliente": "Carlos", "monto": 800, "fecha": "2026"},
            ]

        else:
            if not textos or not textos[0].strip():
                log(rid, "⚠️ sin texto extraído")
                data = [
                    {"cliente": "Carlos Pérez", "monto": 1200, "fecha": "2026-01-15"},
                    {"cliente": "Ana Gómez", "monto": 2500, "fecha": "2026-02-20"},
                    {"cliente": "Carlos Pérez", "monto": 800, "fecha": "2026-03-10"},
                ]
            else:
                contenido = "\n\n".join(textos)

                log(rid, f"📄 texto len: {len(contenido)}")

            # 🤖 IA
            api_key = os.getenv("GROQ_API_KEY")

            if api_key:
                
                    client = Groq(api_key=api_key)
                    contenido = contenido[:3000]  # 🔥 CLAVE
            
                    log(rid, "🧠 consultando IA...")

                    resp = client.chat.completions.create(
                       model="llama-3.1-8b-instant",
                        messages=[
                            {"role": "system",
                            "content": """
                            Extrae únicamente pagos, clientes, montos y fechas del documento.
                            Devuelve SOLO JSON válido, sin explicación, sin markdown.
                            NO recortes nombres.
                            NO regreses abreviaciones como 'ndez'.
                            NO inventes.
                            
                            Devuelve JSON así:
                            [
                                {"cliente":"Nombre completo","monto":123,"fecha":"YYYY-MM-DD"}
                                ...
                            ]
                            Reglas:
                            - El campo cliente debe contener el nombre completo.
                            - Conserva acentos y apellidos completos.
                            - No recortes nombres.
                            - No devuelvas fragmentos como "rez", "ndez", "mez" o "nchez".
                            - Si no hay fecha, usa "N/A".
                            - Si no estás seguro, no inventes, mejor omite el ítem.
                            """},
                            {"role": "user",
                            "content": contenido[:3000]}
                        ]
                    )
                    try:

                        texto_ia = resp.choices[0].message.content.strip()
                        print("IA RESPUESTA:", texto_ia)

                        match = re.search(r"\[.*\]", texto_ia, re.DOTALL)
                        if match:
                             data = json.loads(match.group(0))
                        else:
                            print("⚠️ IA no devolvió JSON válido")

                    except Exception as e:
                       log(rid, f"🔥 IA ERROR: {e}")

            # fallback
            if not data:
                log(rid, "🧯 regex fallback")

                lineas = contenido.splitlines()
                patron = re.compile(
                r"([A-Za-zÁÉÍÓÚÜÑáéíóúüñ]+(?:\s+[A-Za-zÁÉÍÓÚÜÑáéíóúüñ]+)*)\s+\$?\s*([\d,]+(?:\.\d+)?)"
                )
                for linea in lineas:
                    linea = linea.strip()
                    if not linea: 
                        continue
                
                matches = patron.findall(contenido)
                for cliente, monto in matches:
                    try:
                        cliente = cliente.strip()
                        monto_limpio = monto.replace(",", "")
                        # Evita capturar palabras basura muy cortas
                        if len(cliente) < 3:
                            continue

                        data.append({
                            "cliente": cliente,
                            "monto": float(monto_limpio),
                            "fecha": "N/A"
                        })
                    except Exception as e:
                        log(rid, f"⚠️ fallback item inválido: {e}")

        # fallback final
        if not data:
            log(rid, "⚠️ DEMO")
            data = [
                {"cliente": "Carlos Pérez", "monto": 1200, "fecha": "2026-01-15"},
                {"cliente": "Ana Gómez", "monto": 2500, "fecha": "2026-02-20"},
                {"cliente": "Carlos Pérez", "monto": 800, "fecha": "2026-03-10"},
            ]

        # resumen
        resumen = {}
        for item in data:
        
            resumen[item["cliente"]] = resumen.get(item["cliente"], 0) + item["monto"]

        resumen_lista = [{"cliente": k, "total": v} for k, v in resumen.items()]

        log(rid, f"📊 {resumen_lista}")

        ultimo_resumen = resumen_lista

        # excel
        df = pd.DataFrame(data)
        df.to_excel("reporte.xlsx", index=False)

        log(rid, f"⏱ total {round(time.time()-start,2)}s")

        return {
            "data": data,
            "resumen": resumen_lista
        }

    except Exception as e:
        log(rid, f"🔥 ERROR ANALIZAR: {e}")
        return {"data": [], "resumen": []}

# =============================
# DASHBOARD
# =============================
@app.get("/descargar-dashboard")
def dashboard():
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
# EXCEL
# =============================
@app.get("/descargar-excel")
def excel():
    if not os.path.exists("reporte.xlsx"):
        return {"error": "No existe"}

    return FileResponse(
        "reporte.xlsx",
        media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        filename="reporte.xlsx"
    )

# =============================
# CHAT
# =============================
@app.post("/chat")
async def chat(pregunta: dict):
    global textos

    rid = log_request("CHAT")

    try:
        if not textos or not "\n".join(textos).strip():

            return {"respuesta": "Sube un PDF primero"}

        api_key = os.getenv("GROQ_API_KEY")

        if not api_key:
            log(rid, "🚨 sin API key")
            return {"respuesta": "Error: API Key no configurada"}

        client = Groq(api_key=api_key)

        contenido = "\n\n".join(textos)

        query = (pregunta or {}).get("mensaje", "")

        log(rid, f"🧠 {query}")

        resp = client.chat.completions.create(
            model="llama-3.1-8b-instant",
            messages=[
                {
                    "role": "system",
                    "content": """
                Responde únicamente usando la información de los archivos subidos.
                Si el usuario pregunta por datos concretos, responde con los datos encontrados.
                No propongas consultas SQL a menos que el usuario pida explícitamente una consulta SQL.
                Si no encuentras la respuesta en los archivos, di que no aparece en los archivos.
                """
                },

                {"role": "user", "content": f"{contenido}\n\nPregunta: {query}"}
            ]
        )

        log(rid, "🤖 OK")

        return {"respuesta": resp.choices[0].message.content}

    except Exception as e:
        log(rid, f"🔥 ERROR CHAT: {e}")
        return {"respuesta": f"Error IA: {str(e)}"}