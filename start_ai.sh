#!/bin/bash
export HSA_OVERRIDE_GFX_VERSION=11.0.0

echo "🚀 Starting AI tools..."

# 1. Ollama (Background)
if command -v ollama &> /dev/null; then
    echo "▶ Starting Ollama engine..."
    ollama serve > ollama.log 2>&1 &
    OLLAMA_PID=$!
    sleep 3
else
    echo "❌ Ollama is not installed!"
fi

# 2. Open WebUI (Background)
if [ -d "open-webui/venv" ]; then
    echo "▶ Starting Open WebUI..."
    source open-webui/venv/bin/activate
    open-webui serve > open-webui.log 2>&1 &
    WEBUI_PID=$!
    deactivate
    echo "🌐 Open WebUI will be available at http://localhost:8080 soon."
else
    echo "❌ Open WebUI venv is not found!"
fi

# --- Cleanup function for graceful exit ---
cleanup() {
    echo -e "\n🛑 Stopping AI tools..."
    [ -n "$OLLAMA_PID" ] && kill $OLLAMA_PID 2>/dev/null
    [ -n "$WEBUI_PID" ] && kill $WEBUI_PID 2>/dev/null
    echo "✅ Ollama and Open WebUI stopped."
    exit
}
# Trap Ctrl+C (SIGINT) and other signals
trap cleanup SIGINT SIGTERM EXIT

echo "--------------------------------------------------------"
echo "💡 You can start using Chat UI while ComfyUI is loading!"
echo "--------------------------------------------------------"

# 3. ComfyUI (Foreground)
if [ -d "comfyui/venv" ]; then
    echo "▶ Starting ComfyUI (Heavy registry fetch might occur)..."
    source comfyui/venv/bin/activate
    # Run ComfyUI in foreground to keep the container alive and show logs
    python comfyui/main.py --listen 0.0.0.0
else
    echo "❌ ComfyUI venv is not found!"
fi
