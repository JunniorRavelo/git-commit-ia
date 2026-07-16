#!/usr/bin/env python3
import os
import sys
import subprocess
import tempfile
import httpx
from openai import OpenAI

__version__ = "1.0.0"

# 0. Manejo de argumentos: --version / -V / version
if len(sys.argv) > 1 and sys.argv[1] in ("--version", "-V", "version"):
    print(f"git-ai v{__version__}")
    sys.exit(0)

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
# La API key DEBE proporcionarse vía NVIDIA_API_KEY; no se embebe ningún valor.
_API_KEY = os.getenv("NVIDIA_API_KEY")
if not _API_KEY:
    print("❌ Error: define la variable de entorno NVIDIA_API_KEY antes de ejecutar el script.")
    print("   Ejemplo: export NVIDIA_API_KEY=\"nvapi-...\"")
    sys.exit(1)
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
    "1. Una primera línea concisa (máximo 250 caracteres) en minúsculas.\n"
    "2. Una línea en blanco.\n"
    "3. Un cuerpo detallado con viñetas (-) que explique el PORQUÉ del cambio y los impactos técnicos clave a detalle.\n\n"
    f"Escribe todo el mensaje en {_LANG_NAME}. Responde ÚNICAMENTE con el mensaje del commit, sin bloques de código de markdown (```), sin introducciones ni saludos."
)

def generar_commit(diff_text: str) -> str:
    """Llama a la API y devuelve el mensaje del commit (streaming por stdout)."""
    print(f"{_GREEN_COLOR}--- MENSAJE PROPUESTO ---{_RESET_COLOR}")
    completion = client.chat.completions.create(
        model=_MODEL,
        messages=[
            {"role": "system", "content": SYSTEM_PROMPT},
            {"role": "user", "content": f"Aquí está el git diff:\n{diff_text}"}
        ],
        temperature=0.2,
        top_p=1,
        max_tokens=2048,
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
    return commit_message

def editar_commit(mensaje: str) -> str:
    """Abre $EDITOR (o nano/vim) para que el usuario edite el mensaje."""
    editor = os.getenv("EDITOR") or os.getenv("VISUAL") or "nano"
    # Sufijo .txt para que los editores lo traten como texto plano.
    with tempfile.NamedTemporaryFile(
        mode="w", suffix=".txt", delete=False, encoding="utf-8"
    ) as tmp:
        tmp.write(mensaje)
        tmp_path = tmp.name

    try:
        subprocess.run([editor, tmp_path], check=True)
        with open(tmp_path, "r", encoding="utf-8") as f:
            nuevo = f.read().strip()
        return nuevo if nuevo else mensaje
    finally:
        try:
            os.unlink(tmp_path)
        except OSError:
            pass

try:
    print(f"🤖 Analizando cambios con {_MODEL}...\n")
    commit_message = generar_commit(diff_text)

    while True:
        confirm = input(
            "¿Quieres usar este mensaje? (s=confirmar / n=cancelar / e=editar / r=regenerar): "
        ).strip().lower()

        if confirm == 's':
            commit_exec = subprocess.run(
                ["git", "commit", "-m", commit_message],
                capture_output=True, text=True, check=True
            )
            print(f"\n{_GREEN_COLOR}✔ Successfully committed!{_RESET_COLOR}")
            print(commit_exec.stdout)
            break
        elif confirm == 'e':
            commit_message = editar_commit(commit_message)
            print(f"\n{_GREEN_COLOR}--- MENSAJE EDITADO ---{_RESET_COLOR}")
            print(commit_message)
            print(f"{_GREEN_COLOR}------------------------{_RESET_COLOR}\n")
            # Tras editar, volvemos a preguntar (loop).
        elif confirm == 'r':
            print("\n♻️  Regenerando mensaje...\n")
            commit_message = generar_commit(diff_text)
        else:
            print("\n❌ Commit cancelado.")
            break
except Exception as e:
    print(f"\n❌ Error de comunicación con la API: {e}")
except KeyboardInterrupt:
    print("\n\n❌ Operación cancelada por el usuario.")
