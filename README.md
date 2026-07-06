# rocm-ai-docker

ROCm-based local AI server environment.

Last checked: 2026-07-06

## Layout

Project root on the host:

```text
~/@sync/rocm-ai-docker
```

Main container:

```text
rocm-ai-docker_server
```

Important bind mounts:

```text
host project root         -> container: ~/share
host project root/.ollama -> container: ~/.ollama
```

The container uses host networking, so services listen directly on the host network. `docker port rocm-ai-docker_server` may show no mappings.

## Service URLs

Use the current hostname or LAN IP of the machine in place of `<host-or-ip>`. Do not assume this value is stable across network changes.

```text
ComfyUI:    http://<host-or-ip>:8188/
Ollama API: http://<host-or-ip>:11434/
Open WebUI: http://<host-or-ip>:8080/
Hunyuan3D:  http://<host-or-ip>:8081/
```

Useful API checks:

```bash
curl http://<host-or-ip>:11434/api/version
curl http://<host-or-ip>:11434/api/tags
curl http://<host-or-ip>:8188/system_stats
curl http://<host-or-ip>:8188/api/models
```

## Start and Stop

From the project root:

```bash
./DockerRun.sh --server
sudo docker stop rocm-ai-docker_server
```

Open a shell in the running container:

```bash
sudo docker exec -it rocm-ai-docker_server bash
```

Check related processes:

```bash
sudo docker exec rocm-ai-docker_server pgrep -af 'ollama|comfy|Comfy|open-webui|hunyuan'
```

## GPU Checks

ROCm SMI is available on the host:

```bash
rocm-smi
rocm-smi --showuse --showmemuse --showtemp --showpower --showclocks
rocm-smi --showpids
rocm-smi --showmeminfo vram
```

Observed on 2026-07-06:

```text
GPU: Radeon 8060S Graphics, exposed through ROCm as cuda:0 in PyTorch
VRAM total: 103,079,215,104 bytes
VRAM used:  42,193,600,512 bytes
Temperature: about 36 C
GPU use: 0%
```

`rocm-smi --showpids` can list GPU users on this machine, but per-process VRAM may be reported as `UNKNOWN`.

## Ollama

Common commands:

```bash
sudo docker exec rocm-ai-docker_server ollama list
sudo docker exec rocm-ai-docker_server ollama ps
sudo docker exec rocm-ai-docker_server ollama pull <model>
sudo docker exec rocm-ai-docker_server ollama run <model>
sudo docker exec rocm-ai-docker_server ollama stop <model>
```

`OLLAMA_KEEP_ALIVE=-1` is set by `start_ai.sh`, so loaded models stay resident until explicitly stopped or the service/container is restarted.

Installed models as of 2026-07-06:

| Model | Size | Notes |
| --- | ---: | --- |
| `gpt-oss:20b` | 13 GB | 20.9B, MXFP4 |
| `qwen3.6:35b` | 23 GB | 36.0B, Q4_K_M |
| `gemma4:26b` | 17 GB | 25.8B, Q4_K_M |
| `qwen3.5:35b` | 23 GB | 36.0B, Q4_K_M |
| `llama3.3:70b` | 42 GB | 70.6B, Q4_K_M |
| `qwen3.5:27b` | 17 GB | 27.8B, Q4_K_M |
| `qwen3.5:0.8b` | 1.0 GB | 873M, Q8_0 |
| `qwen2.5:0.5b` | 397 MB | 494M, Q4_K_M |

Models added on 2026-07-06:

```bash
sudo docker exec rocm-ai-docker_server ollama pull gemma4:26b
sudo docker exec rocm-ai-docker_server ollama pull qwen3.6:35b
sudo docker exec rocm-ai-docker_server ollama pull gpt-oss:20b
```

Reason for these additions:

| Model | Why |
| --- | --- |
| `gemma4:26b` | Adds a Gemma-family model in the same practical size range as the existing 27B/35B models. |
| `qwen3.6:35b` | Direct successor candidate for `qwen3.5:35b`, same broad size class. |
| `gpt-oss:20b` | Adds an OpenAI open-weight reasoning/tool-use oriented model without moving into very large model sizes. |

Other candidates that may be worth testing later:

| Model | Notes |
| --- | --- |
| `qwen3.6:27b` | Direct successor candidate for `qwen3.5:27b`. |
| `devstral:24b` | Coding-agent oriented Mistral model. |
| `deepseek-r1:32b` | Reasoning-specialized distilled Qwen 32B model. |

## ComfyUI

Model root:

```text
~/@sync/rocm-ai-docker/comfyui/models
```

Installed ComfyUI models as of 2026-07-06:

Checkpoints:

```text
playground-v2.5-1024px-aesthetic.fp16.safetensors
sd_xl_turbo_1.0_fp16.safetensors
```

Diffusion models:

```text
flux1-dev.safetensors
```

Text encoders / CLIP:

```text
clip_l.safetensors
t5xxl_fp16.safetensors
```

VAE:

```text
ae.safetensors
```

LoRA:

```text
flux/FluxIconMaker.safetensors
flux/IconAndLogos.safetensors
sdxl/AppIconsSDXL.safetensors
sdxl/IconsRedmond.safetensors
sdxl/LogoRedmondV2.safetensors
sdxl/MinimalistFlatIconsXL.safetensors
```

Empty on 2026-07-06:

```text
controlnet
upscale_models
clip_vision
style_models
embeddings
```

## Sources Checked

- https://ollama.com/library/gemma4
- https://ollama.com/library/gpt-oss
- https://ollama.com/library/qwen3.6
- https://ollama.com/library/devstral
- https://ollama.com/library/deepseek-r1
- https://openai.com/index/introducing-gpt-oss/
