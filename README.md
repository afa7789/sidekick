# Local AI stack

A super lightweight and fast environment for running programming LLMs (such as `Qwen2.5-Coder`) locally on your Mac, integrated directly into your terminal via OpenCode.

## 🪄 Discovering the Best Model for Your Machine

The choice of which model version to use (7B, 14B, 30B...) depends exclusively on the amount of Unified Memory (RAM/VRAM) your computer has.

To find out exactly what the "sweet spot" is for your hardware, **we highly recommend using [llmfit](https://github.com/AlexsJones/llmfit)**.

Run in your terminal:
```bash
npx llmfit
```

`llmfit` will perform a quick analysis of your computer's hardware and recommend the exact `.gguf` file quantization that will run smoothly without choking your development environment (Example common suggestions for the 16GB M2: `q4_k_m` or `q5_k_m` in the 7B and 14B variants).

## ⚙️ Centralized Configuration

1. At the root of the project, you will see a file called `.env.example`. Copy it or simply rename it to `.env`:
```bash
cp .env.example .env
```
2. Open your newly created `.env` file.
3. Replace the `MODEL_FILE` variable value exactly with the name that **`llmfit`** recommended during its inspection:
```env
MODEL_FILE="qwen2.5-coder-14b-instruct-q4_k_m.gguf"
```
*(From this point forward, all project scripts will read from this single "source of truth").*

4. Download the official repository file to your machine using our robust bash script:
```bash
./scripts/download-model.sh
```

## 🚀 Daily Usage

### Start Everything (Local Server + Terminal Chat)
Starts the `llama.cpp` engine server invisibly in the background and then immediately opens the OpenCode CLI.
```bash
./scripts/start-all.sh
```

### Stop Everything
Safely shuts down the AI server and completely frees up your RAM.
```bash
./scripts/stop-all.sh
```

### Start Only the Local AI Server
Useful if you want to connect the AI to your native VS Code, Cursor, or Cline extensions via port `8080`.
```bash
./scripts/start-llama.sh
```

## 📋 Diagnostics and Performance Logs

To track in real-time how hard the machine is working (tokens/s, processing, and temps):
```bash
tail -f logs/llama.log
```

To verify in the raw interface if the local API is online and compatible with the OpenAI standard:
```bash
curl http://localhost:8080/v1/models
```

## 💡 Notes (Troubleshooting)

**If memory gets too full (Sudden crashes):**
This happens when the "context window" clashes with the machine's physical memory needed for other apps on macOS. Edit the `start-llama.sh` file and cut the context parameter in half:
- Change ` -c 16384 ` → to ` -c 8192 `

**If word generation is too slow:**
Add the following *flags* to the execution in the `start-llama.sh` file to give high priority to the threads on your Mac logic board:
- `--mlock` (Locks the model firmly in RAM and prevents it from swapping to the SSD)
- `--prio 2` (Guarantees high priority in Mac processor distribution)

**If OpenCode text is black / hard to read on a dark terminal:**
While running OpenCode, simply type `/theme` and press **Enter** to select a dark-mode friendly theme (like `system`, `tokyonight`, or `one-dark`).
