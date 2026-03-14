#!/bin/bash
export HSA_OVERRIDE_GFX_VERSION=11.0.0

echo "🚀 Starting AI tools..."

# 1. Ollama
if command -v ollama &> /dev/null; then
    echo "▶ Starting Ollama..."
    ollama serve > ollama.log 2>&1 &
    sleep 5
else
    echo "❌ Ollama is not installed!"
fi

# 2. Open WebUI
if [ -d "open-webui/venv" ]; then
    echo "▶ Starting Open WebUI..."
    source open-webui/venv/bin/activate
    open-webui serve > open-webui.log 2>&1 &
    deactivate
else
    echo "❌ Open WebUI venv is not found!"
fi

# 3. ComfyUI
if [ -d "comfyui/venv" ]; then
    echo "▶ Starting ComfyUI..."
    source comfyui/venv/bin/activate
    python comfyui/main.py --listen 0.0.0.0
else
    echo "❌ ComfyUI venv is not found!"
fi
