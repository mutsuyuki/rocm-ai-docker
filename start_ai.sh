#!/bin/bash
# HSA env vars (HSA_OVERRIDE_GFX_VERSION, HSA_ENABLE_SDMA) are set via DockerRun.sh
export OLLAMA_HOST=0.0.0.0
export OLLAMA_KEEP_ALIVE=-1

echo "🚀 Starting AI tools (ROCm High-Performance Mode)..."

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
    open-webui/venv/bin/open-webui serve > open-webui.log 2>&1 &
    WEBUI_PID=$!
    echo "🌐 Open WebUI will be available at http://localhost:8080 soon."
else
    echo "❌ Open WebUI venv is not found!"
fi

# 3. Hunyuan3D-2.1 API server (Background)
if [ -d "hunyuan3d/venv" ]; then
    echo "▶ Starting Hunyuan3D-2.1 API server (port 8081)..."
    # Cache models on the shared volume so they survive container rebuilds
    export TORCH_ROCM_AOTRITON_ENABLE_EXPERIMENTAL=1
    export HF_HOME="$(pwd)/hunyuan3d/.cache/huggingface"
    export HY3DGEN_MODELS="$(pwd)/hunyuan3d/.cache/hy3dgen"
    export U2NET_HOME="$(pwd)/hunyuan3d/.cache/u2net"
    LOG_PATH="$(pwd)/hunyuan3d.log"
    cd hunyuan3d
    venv/bin/python api_server.py \
        --host 0.0.0.0 \
        --port 8081 \
        --device cuda \
        --cache-path "$(pwd)/gradio_cache" \
        > "$LOG_PATH" 2>&1 &
    cd ..
    HUNYUAN_PID=$!
    echo "🧊 Hunyuan3D-2.1 API at http://localhost:8081 (loading model...)"
else
    echo "⚠️  Hunyuan3D-2.1 venv not found. Skipping."
fi

# --- Cleanup function for graceful exit ---
cleanup() {
    echo -e "\n🛑 Stopping AI tools..."
    [ -n "$OLLAMA_PID" ] && kill $OLLAMA_PID 2>/dev/null
    [ -n "$WEBUI_PID" ] && kill $WEBUI_PID 2>/dev/null
    [ -n "$HUNYUAN_PID" ] && kill $HUNYUAN_PID 2>/dev/null
    echo "✅ All services stopped."
    exit
}
# Trap Ctrl+C (SIGINT) and other signals
trap cleanup SIGINT SIGTERM EXIT

echo "--------------------------------------------------------"
echo "💡 You can start using Chat UI while ComfyUI is loading!"
echo "--------------------------------------------------------"

# 4. ComfyUI (Foreground)
if [ -d "comfyui/venv" ]; then
    echo "▶ Starting ComfyUI (Heavy registry fetch might occur)..."
    # Run ComfyUI in foreground to keep the container alive and show logs
    comfyui/venv/bin/python comfyui/main.py --listen 0.0.0.0
else
    echo "❌ ComfyUI venv is not found!"
fi
