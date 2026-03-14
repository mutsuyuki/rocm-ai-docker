NUM_GPUS=$(nvidia-smi -L | wc -l)

xhost +

for (( GPU_ID=0; GPU_ID<NUM_GPUS; GPU_ID++ ))
do
    echo "------------------------------------------------------------------"
    echo "Running on GPU ${GPU_ID}"
    echo "------------------------------------------------------------------"

    docker run \
    --rm \
    --env=DISPLAY=${DISPLAY} \
    --env=NVIDIA_DRIVER_CAPABILITIES=all \
    --mount=type=bind,src=/tmp/.X11-unix,dst=/tmp/.X11-unix \
    --gpus=all \
    --shm-size=1g \
    nvidia/samples:nbody \
    nbody -numbodies=$((256*800)) -benchmark -device=${GPU_ID}
done
