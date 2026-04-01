#!/bin/bash
set -e

echo "🎨 Checking environment setup..."

# 1. Open WebUI setup (Skip if already exists)
if [ ! -d "open-webui/venv" ]; then
    echo "🌐 Setting up Open WebUI..."
    mkdir -p open-webui
    python3 -m venv open-webui/venv
    open-webui/venv/bin/pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu
    open-webui/venv/bin/pip install open-webui
else
    echo "✅ Open WebUI environment already exists. Skipping setup."
fi

# 2. ComfyUI setup (Skip if already exists)
if [ ! -d "comfyui/venv" ]; then
    echo "🖼️ Setting up ComfyUI..."
    [ ! -d "comfyui" ] && git clone https://github.com/comfyanonymous/ComfyUI.git comfyui
    python3 -m venv comfyui/venv
    comfyui/venv/bin/pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/rocm7.2
    comfyui/venv/bin/pip install -r comfyui/requirements.txt
    
    # Custom Nodes
    cd comfyui/custom_nodes
    [ ! -d "ComfyUI-Manager" ] && git clone https://github.com/ltdrdata/ComfyUI-Manager.git
    [ ! -d "ComfyUI-VideoHelperSuite" ] && git clone https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git
    ../venv/bin/pip install -r ComfyUI-VideoHelperSuite/requirements.txt
    cd ../..
else
    echo "✅ ComfyUI environment already exists. Skipping setup."
fi

echo "🚀 Ready! Use './start_ai.sh' to launch tools."
