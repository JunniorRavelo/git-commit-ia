#!/usr/bin/env python3
import os
import sys
import subprocess
import httpx
from openai import OpenAI

# 1. Capturar los cambios en stage (git diff --cached)
try:
    diff_result = subprocess.run(["git", "diff", "--cached"], capture_output=True, text=True, check=True)
    diff_text = diff_result.stdout.strip()
except subprocess.CalledProcessError:
    print("❌ Error: Asegúrate de estar dentro de un repositorio de Git.")
    sys.exit(1)

if not diff_text:
    print("❌ No hay archivos en stage. Usa 'git add' primero.")
    sys.exit(0)

_USE_COLOR = sys.stdout.isatty() and os.getenv("NO_COLOR") is None
_GREEN_COLOR = "\033[92m" if _USE_COLOR else ""
_RESET_COLOR = "\033[0m" if _USE_COLOR else ""

# 2. Configuración desde variables de entorno (con defaults)
_BASE_URL = os.getenv("NVIDIA_BASE_URL", "https://integrate.api.nvidia.com/v1")
_MODEL = os.getenv("COMMIT_IA_MODEL", "z-ai/glm-5.2")
_LANG = os.getenv("COMMIT_IA_LANG", "es")

# Mapa de códigos ISO 639-1 -> nombre del idioma (para el prompt)
_LANG_NAMES = {
    "es": "español", "en": "English", "fr": "français", "de": "Deutsch",
    "pt": "português", "it": "italiano", "pl": "polski", "hi": "हिन्दी",
    "ja": "日本語", "zh": "中文", "ru": "Русский", "ko": "한국어",
    "ar": "العربية", "nl": "Nederlands", "tr": "Türkçe",
}
_LANG_NAME = _LANG_NAMES.get(_LANG, _LANG)  # si no está listado, pasa el código tal cual

# 3. Inicializar cliente ignorando proxies corruptos del sistema
# La API key se lee de NVIDIA_API_KEY; si no está definida, se usa un valor
# por defecto embebido (útil para desarrollo, NO recomendado para producción).
_API_KEY = os.getenv("NVIDIA_API_KEY", "REDACTED-NVIDIA-API-KEY")
client = OpenAI(
    base_url=_BASE_URL,
    api_key=_API_KEY,
    http_client=httpx.Client(trust_env=False)  # 🔥 Esto ignora proxies mal configurados en Debian
)

SYSTEM_PROMPT = (
    "Eres un ingeniero de software experto. Tu tarea es escribir un mensaje de commit de Git "
    "altamente profesional basado en el 'git diff' proporcionado.\n\n"
    "Debes usar estrictamente el formato de 'Conventional Commits' (ej. feat(scope): desc, fix(scope): desc, docs(scope): desc).\n"
    "El mensaje DEBE incluir:\n"
    "1. Una primera línea concisa (máximo 50 caracteres) en minúsculas.\n"
    "2. Una línea en blanco.\n"
    "3. Un cuerpo detallado con viñetas (-) que explique el PORQUÉ del cambio y los impactos técnicos clave.\n\n"
    f"Escribe todo el mensaje en {_LANG_NAME}. Responde ÚNICAMENTE con el mensaje del commit, sin bloques de código de markdown (```), sin introducciones ni saludos."
)

print(f"🤖 Analizando cambios con {_MODEL}...\n")
print(f"{_GREEN_COLOR}--- MENSAJE PROPUESTO ---{_RESET_COLOR}")

try:
    completion = client.chat.completions.create(
        model=_MODEL,
        messages=[
            {"role": "system", "content": SYSTEM_PROMPT},
            {"role": "user", "content": f"Aquí está el git diff:\n{diff_text}"}
        ],
        temperature=0.2,
        top_p=1,
        max_tokens=1024,
        seed=42,
        stream=True
    )

    commit_message = ""
    for chunk in completion:
        if not getattr(chunk, "choices", None): continue
        if len(chunk.choices) == 0 or getattr(chunk.choices[0], "delta", None) is None: continue
        delta = chunk.choices[0].delta
        if getattr(delta, "content", None) is not None:
            content = delta.content
            print(content, end="", flush=True)
            commit_message += content

    print(f"\n{_GREEN_COLOR}------------------------{_RESET_COLOR}\n")

    confirm = input("¿Quieres usar este mensaje para el commit? (s/n): ").strip().lower()
    if confirm == 's':
        commit_exec = subprocess.run(["git", "commit", "-m", commit_message], capture_output=True, text=True, check=True)
        print(f"\n{_GREEN_COLOR}✔ Successfully committed!{_RESET_COLOR}")
        print(commit_exec.stdout)
    else:
        print("\n❌ Commit cancelado.")
except Exception as e:
    print(f"\n❌ Error de comunicación con la API: {e}")
except KeyboardInterrupt:
    print("\n\n❌ Operación cancelada por el usuario.")
