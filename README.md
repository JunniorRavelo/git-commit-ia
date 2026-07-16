# git-ai

Extensión de Git CLI que genera mensajes de commit automáticamente usando IA
(GLM-5.2 a través de la API de NVIDIA). Analiza tu `git diff --cached` y propone
un mensaje siguiendo la convención **Conventional Commits** en español, con
streaming en tiempo real. Si lo aceptas, hace el commit por ti.

## ¿Cómo funciona?

1. Haces `git add` de los archivos que quieres commitear (como siempre).
2. Ejecutas `git ai` (o `git-ai`).
3. La IA lee el diff en stage y redacta un mensaje profesional.
4. Confirmas con `s` y se ejecuta el commit, o lo cancelas con `n`.

## Requisitos

- Python 3.8+
- `git`
- Una API key de NVIDIA (la obtienes en https://build.nvidia.com)
- La librería `openai` de Python

## Instalación

### 1. Instalar la librería de Python

```bash
# Debian/Ubuntu (si pip está bloqueado por PEP 668)
pip3 install openai --break-system-packages

# O en un entorno virtual (recomendado)
python3 -m venv .venv
source .venv/bin/activate
pip install openai
```

### 2. Configurar tu API key

El script requiere que proporciones tu propia API key mediante una variable de
entorno (no se embebe ninguna key en el código):

```bash
export NVIDIA_API_KEY="tu-api-key-aqui"
```

Añádelo a tu `~/.bashrc` o `~/.zshrc` para que persista entre sesiones:

```bash
echo 'export NVIDIA_API_KEY="tu-api-key-aqui"' >> ~/.bashrc
source ~/.bashrc
```

### 3. Instalar el comando como subcomando de Git

Git reconoce como subcomandos cualquier ejecutable en el `PATH` cuyo nombre
empiece por `git-`. Copia (o enlaza) el script con el nombre `git-ai`:

```bash
chmod +x git-ai.sh
sudo ln -s "$(pwd)/git-ai.sh" /usr/local/bin/git-ai
```

Ahora puedes usarlo desde cualquier repositorio:

```bash
git ai
```

> Alternativa sin permisos de root: añade el directorio del script a tu `PATH`
> o crea un enlace dentro de `~/.local/bin`:
>
> ```bash
> mkdir -p ~/.local/bin
> ln -s "$(pwd)/git-ai.sh" ~/.local/bin/git-ai
> # asegúrate de tener ~/.local/bin en el PATH
> ```

## Variables de entorno

| Variable           | Descripción                                  | Por defecto                                |
|--------------------|----------------------------------------------|--------------------------------------------|
| `NVIDIA_API_KEY`   | **Obligatoria.** API key de NVIDIA.          | —                                          |
| `NVIDIA_BASE_URL`  | URL base de la API.                          | `https://integrate.api.nvidia.com/v1`      |
| `COMMIT_IA_MODEL`  | Modelo a usar para generar el commit.        | `z-ai/glm-5.2`                             |
| `COMMIT_IA_LANG`   | Idioma del mensaje de commit (código ISO 639-1). | `es`                                   |
| `NO_COLOR`         | Si está definida, desactiva los colores.     | —                                          |

### Idiomas soportados

El mensaje del commit se puede generar en distintos idiomas mediante `COMMIT_IA_LANG`.
La interfaz del script (mensajes y prompts) siempre está en español; solo cambia el
idioma del mensaje de commit generado por la IA.

| Código | Idioma     | Código | Idioma     |
|--------|------------|--------|------------|
| `es`   | Español    | `ja`   | 日本語     |
| `en`   | English    | `zh`   | 中文       |
| `fr`   | Français   | `ru`   | Русский    |
| `de`   | Deutsch    | `ko`   | 한국어     |
| `pt`   | Português  | `ar`   | العربية    |
| `it`   | Italiano   | `nl`   | Nederlands |
| `pl`   | Polski     | `tr`   | Türkçe     |
| `hi`   | हिन्दी     |        |            |

También acepta cualquier otro código ISO 639-1 no listado (la IA lo interpretará).

```bash
# Commit en inglés
export COMMIT_IA_LANG=en
git ai

# Commit en francés (solo para esta ejecución)
COMMIT_IA_LANG=fr git ai
```

## Uso

```bash
git add <archivos>
git ai
```

Ejemplo de salida:

```
🤖 Analizando cambios con z-ai/glm-5.2...

--- MENSAJE PROPUESTO ---
feat(auth): agregar validación de token jwt

- Se añade middleware para verificar la firma del token en cada petición.
- Se rechazan las solicitudes con token expirado devolviendo 401.
- Se documenta el flujo de autenticación en el README.

------------------------

¿Quieres usar este mensaje para el commit? (s/n): s
✔ Successfully committed!
```

## Seguridad

- La API key se carga desde la variable de entorno `NVIDIA_API_KEY`.
  **No la hardcodees** en el script ni la commitees.
- Si publicas este proyecto, asegúrate de no incluir tu `.env` ni tu
  `~/.bashrc` con la key real.

## Licencia

MIT
