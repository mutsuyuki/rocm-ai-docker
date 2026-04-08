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
    comfyui/venv/bin/pip install --upgrade pip uv
    comfyui/venv/bin/pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/rocm7.2
    comfyui/venv/bin/pip install -r comfyui/requirements.txt

    # Custom Nodes
    cd comfyui/custom_nodes
    [ ! -d "ComfyUI-Manager" ] && git clone https://github.com/ltdrdata/ComfyUI-Manager.git
    [ ! -d "ComfyUI-VideoHelperSuite" ] && git clone https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git
    ../venv/bin/pip install -r ComfyUI-VideoHelperSuite/requirements.txt
    ../venv/bin/pip install gitpython toml
    cd ../..
else
    echo "✅ ComfyUI environment already exists. Skipping setup."
fi

# 3. Hunyuan3D-2.1 setup (Skip if already exists)
if [ ! -d "hunyuan3d/venv" ]; then
    echo "🧊 Setting up Hunyuan3D-2.1..."
    [ ! -d "hunyuan3d" ] && git clone https://github.com/Tencent-Hunyuan/Hunyuan3D-2.1.git hunyuan3d
    python3.10 -m venv hunyuan3d/venv
    hunyuan3d/venv/bin/pip install --upgrade pip
    hunyuan3d/venv/bin/pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/rocm7.2

    # Exclude ROCm/Blender-incompatible packages
    grep -v -E "^(cupy-cuda|bpy==|--extra-index-url)" hunyuan3d/requirements.txt \
        > /tmp/hunyuan3d_requirements_rocm.txt
    hunyuan3d/venv/bin/pip install -r /tmp/hunyuan3d_requirements_rocm.txt

    # Create bpy stub (bpy is Blender-only, not needed for API server)
    BPY_STUB="hunyuan3d/venv/lib/python3.10/site-packages/bpy"
    mkdir -p "$BPY_STUB"
    echo "# Stub: allows import bpy outside Blender" > "$BPY_STUB/__init__.py"

    # Build custom_rasterizer (CUDA kernel compiled via hipcc on ROCm)
    cd hunyuan3d/hy3dpaint/custom_rasterizer
    ../../venv/bin/pip install --no-build-isolation .
    cd ../../..

    # Build DifferentiableRenderer (pure C++, no CUDA needed)
    cd hunyuan3d/hy3dpaint/DifferentiableRenderer
    INCLUDES=$(../../venv/bin/python3 -m pybind11 --includes)
    SUFFIX=$(../../venv/bin/python3 -c "import sysconfig; print(sysconfig.get_config_var('EXT_SUFFIX'))")
    c++ -O3 -Wall -shared -std=c++11 -fPIC $INCLUDES mesh_inpaint_processor.cpp -o mesh_inpaint_processor$SUFFIX
    cd ../../..

    # Download RealESRGAN weight for texture super-resolution
    mkdir -p hunyuan3d/hy3dpaint/ckpt && wget -q -O hunyuan3d/hy3dpaint/ckpt/RealESRGAN_x4plus.pth https://github.com/xinntao/Real-ESRGAN/releases/download/v0.1.0/RealESRGAN_x4plus.pth

    # Create output directory for generated models
    mkdir -p hunyuan3d/gradio_cache

    echo "✅ Hunyuan3D-2.1 setup complete (ROCm + texture support)."
else
    echo "✅ Hunyuan3D-2.1 environment already exists. Skipping setup."
fi

echo "🚀 Ready! Use './start_ai.sh' to launch tools."
