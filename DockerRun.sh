#!/bin/bash

HOST_OS_TYPE=$(uname -s)
BASE_IMAGE="ubuntu:24.04"
IMAGE_REPOSITORY="$(basename "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)")"
IMAGE_TAG="latest"
IMAGE_FULLNAME="${IMAGE_REPOSITORY}:${IMAGE_TAG}"
CONTAINER_NAME="${IMAGE_REPOSITORY}_$(date "+%Y_%m%d_%H%M%S")"


# --- 1. 既存コンテナの再利用 ---
EXISTING_CONTAINER=$(docker ps --format "{{.Image}} {{.Names}}" | grep "^${IMAGE_FULLNAME} " | awk '{print $2}' | head -n 1)
if [ -n "${EXISTING_CONTAINER}" ]; then
    echo "--- Found running container [${EXISTING_CONTAINER}].  ---"
    if command -v xhost >/dev/null 2>&1; then xhost +; fi
    docker exec -it "${EXISTING_CONTAINER}" bash
    exit 0
fi

# --- 2. イメージのビルド ---
docker build \
    --progress=plain \
    --build-arg BASE_IMAGE="${BASE_IMAGE}" \
    --build-arg TIMEZONE="Asia/Tokyo" \
    --build-arg PYTHON_VERSION="3.12" \
    --build-arg NODE_VERSION="22" \
    --build-arg USERNAME="$(whoami)" \
    --build-arg USER_UID="$(id -u)" \
    --build-arg USER_GID="$(id -g)" \
    --tag "${IMAGE_FULLNAME}" \
    .

# --- 3. ホスト側のディレクトリ・ファイル準備 ---
mkdir -p "$(pwd)/.gemini"
touch "$(pwd)/.env"
mkdir -p "$(pwd)/.claude"
touch "$(pwd)/.claude.json"
mkdir -p "$(pwd)/.codex"
mkdir -p "$(pwd)/.ollama"

if command -v xhost >/dev/null 2>&1; then xhost +; fi

# --- 4. 実行オプションの構築（共通部分） ---
DOCKER_RUN_OPTS=(
    --interactive
    --tty
    --rm
    --shm-size="2g"
    --net="host"
    --env="QT_X11_NO_MITSHM=1"
    --env="DISPLAY=${DISPLAY}"
    --env="WAYLAND_DISPLAY=${WAYLAND_DISPLAY}"
    --env="XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR}"
    --env="PULSE_SERVER=${PULSE_SERVER}"
    --env="COLORTERM=truecolor"
    --env="OLLAMA_HOST=0.0.0.0"
    --env-file="$(pwd)/.env"
    --mount="type=bind,src=$(pwd),dst=${HOME}/share"
    --mount="type=bind,src=$(pwd)/.gemini,dst=${HOME}/.gemini"
    --mount="type=bind,src=$(pwd)/.claude,dst=${HOME}/.claude"
    --mount="type=bind,src=$(pwd)/.claude.json,dst=${HOME}/.claude.json"
    --mount="type=bind,src=$(pwd)/.codex,dst=${HOME}/.codex"
    --mount="type=bind,src=$(pwd)/.ollama,dst=${HOME}/.ollama"
    --security-opt="seccomp=unconfined"
    --workdir="${HOME}/share"
    --name="${CONTAINER_NAME}"
)

# --- 5. 条件分岐によるオプションの追加 ---

# Linux固有のオプション（グループ追加、GPUパススルー）
if [ "${HOST_OS_TYPE}" = "Linux" ]; then
    # ホスト側の所属グループをコンテナにも引き継ぐ
    for i in $(id -G); do
        DOCKER_RUN_OPTS+=(--group-add="${i}")
    done

    # GPUの自動判定
    if lspci 2>/dev/null | grep -qi "nvidia"; then
        DOCKER_RUN_OPTS+=(
            --gpus="all"
            --env="NVIDIA_DRIVER_CAPABILITIES=all"
        )
    elif lspci 2>/dev/null | grep -qi "amd\|radeon"; then
        # ホスト側の /dev/kfd のグループIDを動的に取得（取得失敗時は念のためvideo）
        RENDER_GID=$(stat -c "%g" /dev/kfd 2>/dev/null || echo "video")
        DOCKER_RUN_OPTS+=(
            --device="/dev/kfd"
            --device="/dev/dri"
            --group-add="video"
            --group-add="${RENDER_GID}"
            --env="HSA_OVERRIDE_GFX_VERSION=11.0.0"
        )
    fi
fi

# 存在する場合のみマウントするファイル群（LinuxのGUI / オーディオ等）
if [ -e "/tmp/.X11-unix" ]; then
    DOCKER_RUN_OPTS+=(
        --mount="type=bind,src=/tmp/.X11-unix,dst=/tmp/.X11-unix,readonly"
    )
fi
if [ -e "/run/dbus/system_bus_socket" ]; then
    DOCKER_RUN_OPTS+=(
        --mount="type=bind,src=/run/dbus/system_bus_socket,dst=/run/dbus/system_bus_socket"
    )
fi
if [ -e "${HOME}/.Xauthority" ]; then
    DOCKER_RUN_OPTS+=(
        --mount="type=bind,src=${HOME}/.Xauthority,dst=${HOME}/.Xauthority"
    )
fi

# --- 6. コンテナの起動 ---
docker run "${DOCKER_RUN_OPTS[@]}" "${IMAGE_FULLNAME}" \
sh -c "
echo ------- run --------- ;
echo Logged in at \$(pwd) ;
echo Image: ${IMAGE_FULLNAME} ;
bash setup_env.sh ;
bash
"
