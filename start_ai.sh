#!/bin/bash
# rocm-ai-docker サービス起動スクリプト(対称構成版)
#
# 設計:
# - 全サービスをバックグラウンドの「自動再起動ループ」で起動する(対称)。
#   コンテナの命綱は末尾の `tail -f /dev/null`(無害な番人プロセス)。
# - どのサービスも個別に再起動できる:
#     docker exec rocm-ai-docker_server pkill -f "comfyui/main.py"
#   → 5秒後にループが自動で再起動する。他サービスは道連れにならない。
# - サービスがクラッシュしても自動復帰する(supervise-lite)。
#
# 旧構成(ComfyUIをフォアグラウンドにしてコンテナを維持)は、ComfyUIの再起動が
# スタック全体の再起動になる問題があったため廃止(2026-07-17)。

export OLLAMA_HOST=0.0.0.0
export OLLAMA_KEEP_ALIVE=5m
export OLLAMA_MAX_LOADED_MODELS=1  # 2モデル同時常駐でamdgpu OOM(2026-07-07 kernel panic)を起こしたため

echo "🚀 Starting AI tools (ROCm High-Performance Mode / symmetric services)..."

# name, logfile, command(bash -c 文字列) を受け取り、自動再起動ループで回す
run_service() {
    local name="$1"
    local log="$2"
    local cmd="$3"
    (
        while true; do
            echo "▶ [$name] starting ($(date '+%H:%M:%S'))..." | tee -a "$log"
            bash -c "$cmd" >> "$log" 2>&1
            echo "⚠️  [$name] exited (code $?). Restarting in 5s..." | tee -a "$log"
            sleep 5
        done
    ) &
    echo "   [$name] supervisor pid $!"
}

# 1. Ollama (port 11434)
if command -v ollama &> /dev/null; then
    run_service ollama ollama.log "exec ollama serve"
else
    echo "❌ Ollama is not installed!"
fi

# 2. Open WebUI (port 8080)
if [ -d "open-webui/venv" ]; then
    run_service open-webui open-webui.log "exec open-webui/venv/bin/open-webui serve"
    echo "🌐 Open WebUI at http://localhost:8080"
else
    echo "❌ Open WebUI venv is not found!"
fi

# 3. Hunyuan3D-2.1 API (port 8081)
if [ -d "hunyuan3d/venv" ]; then
    export TORCH_ROCM_AOTRITON_ENABLE_EXPERIMENTAL=1
    export HF_HOME="$(pwd)/hunyuan3d/.cache/huggingface"
    export HY3DGEN_MODELS="$(pwd)/hunyuan3d/.cache/hy3dgen"
    export U2NET_HOME="$(pwd)/hunyuan3d/.cache/u2net"
    run_service hunyuan3d hunyuan3d.log \
        "cd hunyuan3d && exec venv/bin/python api_server.py --host 0.0.0.0 --port 8081 --device cuda --cache-path \"\$(pwd)/gradio_cache\""
    echo "🧊 Hunyuan3D-2.1 API at http://localhost:8081 (loading model...)"
else
    echo "⚠️  Hunyuan3D-2.1 venv not found. Skipping."
fi

# 4. Kokoro TTS API (port 8082, CPU)
if [ -d "kokoro-tts/venv" ]; then
    run_service kokoro-tts kokoro-tts.log "exec kokoro-tts/venv/bin/python kokoro-tts/server.py"
    echo "🗣  Kokoro TTS API at http://localhost:8082 (CPU, no VRAM use)"
else
    echo "⚠️  kokoro-tts venv not found. Skipping."
fi

# 5. ComfyUI (port 8188) — 旧フォアグラウンド。今は他と同じバックグラウンド
if [ -d "comfyui/venv" ]; then
    run_service comfyui comfyui.log "exec comfyui/venv/bin/python comfyui/main.py --listen 0.0.0.0"
    echo "🎨 ComfyUI at http://localhost:8188 (loading...)"
else
    echo "❌ ComfyUI venv is not found!"
fi

# --- Cleanup: コンテナ停止時に全ループ+子プロセスを畳む ---
cleanup() {
    echo -e "\n🛑 Stopping AI tools..."
    # サービスの再起動ループ(サブシェル)ごと止める
    kill $(jobs -p) 2>/dev/null
    # 残った実プロセスも念のため
    pkill -f "ollama serve" 2>/dev/null
    pkill -f "open-webui serve" 2>/dev/null
    pkill -f "api_server.py" 2>/dev/null
    pkill -f "kokoro-tts/server.py" 2>/dev/null
    pkill -f "comfyui/main.py" 2>/dev/null
    echo "✅ All services stopped."
    exit 0
}
trap cleanup SIGINT SIGTERM EXIT

echo "--------------------------------------------------------"
echo "💡 All services run as supervised background jobs."
echo "   Restart one:  pkill -f 'comfyui/main.py'  (auto-respawns in 5s)"
echo "--------------------------------------------------------"

# コンテナの命綱(番人)。サービスはすべて上の supervise ループが面倒を見る
tail -f /dev/null
