# Sidekick

A local-first AI writing assistant for roadmaps and notes. Runs entirely on your machine — no cloud, no subscriptions.

**Stack:** [Silverbullet](https://github.com/silverbulletmd/silverbullet) (notes UI) + [llama.cpp](https://github.com/ggml-org/llama.cpp) (local LLM)

**Default model:** [LFM2-24B](https://huggingface.co/liquid-tech/LFM2-24B-GGUF) — Liquid AI's 24B MoE model, fast and strong at instruction following and writing.

---

## ⚙️ Setup

**1. Install dependencies**
```bash
./scripts/install-deps.sh
```

**2. Configure**
```bash
cp .env.example .env
```

Edit `.env`. The key variables:

| Variable | Description |
|---|---|
| `MODEL_FILE` | Name of the `.gguf` file |
| `MODELS_DIR` | Where models are stored (absolute or relative path) |
| `LLAMA_PORT` | llama.cpp API port (default: `8080`) |
| `NOTES_PORT` | Silverbullet UI port (default: `3000`) |
| `NOTES_DIR` | Where your markdown notes live (default: `./notes`) |

> Run `npx llmfit` to find the best model quantization for your hardware.

**3a. Already have a model? Point to it**

No duplication of large files needed. Set `MODELS_DIR` in `.env` depending on your setup:

```env
# If sidekick lives inside local-code/ (local-code/sidekick/)
MODELS_DIR="../models"

# If sidekick is a standalone project elsewhere
MODELS_DIR="/Users/afa/Developer/arthur/local-code/models"
```

**3b. Download the model**
```bash
./scripts/download-model.sh
```

---

## 🚀 Daily Usage

### Start everything
```bash
./scripts/start-all.sh
```
Opens the notes UI at **http://localhost:3000** and starts the LLM server in the background.

### Stop everything
```bash
./scripts/stop-all.sh
```

### Improve a note with AI
```bash
# Default: improves structure and clarity
./scripts/agent.sh notes/roadmap.md

# With custom instruction
./scripts/agent.sh notes/roadmap.md "add estimated timelines to each item"
./scripts/agent.sh notes/idea.md "expand this into a detailed technical spec"
```

The improved version is saved as `<note>-improved.md` alongside the original.

---

## 📋 Diagnostics

```bash
# Check llama.cpp logs
tail -f logs/llama.log

# Check Silverbullet logs
tail -f logs/silverbullet.log

# Verify LLM API is online
curl http://localhost:8080/v1/models
```

---

## 💡 Tips

**Context window too small for long notes?**
Edit `scripts/start-llama.sh` and increase `-c 16384` → `-c 32768`.

**Silverbullet port conflict?**
Change `NOTES_PORT` in `.env`.

**llama.cpp crashing (out of memory)?**
Cut the context in half: `-c 16384` → `-c 8192`.
