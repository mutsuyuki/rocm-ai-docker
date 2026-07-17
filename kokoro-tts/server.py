"""Kokoro TTS API server (OpenAI speech API 互換).

rocm-ai-docker スタックの1サービスとして起動する(start_ai.sh 参照, port 8082)。
GPU不使用(CPU推論)なので Ollama / ComfyUI と VRAM を奪い合わない。

API:
  GET  /health                -> {"status": "ok"}
  GET  /v1/voices             -> {"voices": [...]}
  POST /v1/audio/speech       -> audio/wav (24kHz mono 16bit)
       body: {"input": "text", "voice": "af_bella", "speed": 1.0}
       (OpenAI互換のため "model" フィールドは受け取るが無視する)

モデルは初回起動時に models/ へ自動ダウンロード(計約350MB)。
"""
import io
import json
import os
import urllib.request
import wave

import numpy as np
import uvicorn
from fastapi import FastAPI, HTTPException
from fastapi.responses import Response
from pydantic import BaseModel

HERE = os.path.dirname(os.path.abspath(__file__))
MODEL_DIR = os.path.join(HERE, "models")
FILES = {
    "kokoro-v1.0.onnx": ("https://github.com/thewh1teagle/kokoro-onnx/releases/"
                         "download/model-files-v1.0/kokoro-v1.0.onnx"),
    "voices-v1.0.bin": ("https://github.com/thewh1teagle/kokoro-onnx/releases/"
                        "download/model-files-v1.0/voices-v1.0.bin"),
}

app = FastAPI(title="kokoro-tts")
_kokoro = None


def _ensure_models():
    os.makedirs(MODEL_DIR, exist_ok=True)
    for name, url in FILES.items():
        dst = os.path.join(MODEL_DIR, name)
        if not os.path.exists(dst):
            print(f"[kokoro-tts] downloading {name} ...", flush=True)
            tmp = dst + ".part"
            urllib.request.urlretrieve(url, tmp)
            os.replace(tmp, dst)


def _get():
    global _kokoro
    if _kokoro is None:
        _ensure_models()
        from kokoro_onnx import Kokoro
        _kokoro = Kokoro(os.path.join(MODEL_DIR, "kokoro-v1.0.onnx"),
                         os.path.join(MODEL_DIR, "voices-v1.0.bin"))
        print("[kokoro-tts] model loaded", flush=True)
    return _kokoro


class SpeechRequest(BaseModel):
    input: str
    voice: str = "af_bella"
    speed: float = 1.0
    model: str = "kokoro"           # OpenAI互換のため受けるが未使用
    response_format: str = "wav"    # wav のみ対応
    lang: str = "en-us"


@app.get("/health")
def health():
    return {"status": "ok", "model_loaded": _kokoro is not None}


@app.get("/v1/voices")
def voices():
    k = _get()
    try:
        vs = sorted(k.voices.files.keys()) if hasattr(k.voices, "files") else sorted(list(k.voices))
    except Exception:
        vs = ["af_bella", "af_heart", "af_sarah", "am_adam", "am_michael", "bf_emma"]
    return {"voices": vs}


@app.post("/v1/audio/speech")
def speech(req: SpeechRequest):
    if req.response_format not in ("wav",):
        raise HTTPException(400, "only response_format='wav' is supported")
    text = (req.input or "").strip()
    if not text:
        raise HTTPException(400, "input is empty")
    if len(text) > 2000:
        raise HTTPException(400, "input too long (max 2000 chars)")
    k = _get()
    samples, sr = k.create(text, voice=req.voice, speed=req.speed, lang=req.lang)
    pcm = np.clip(np.asarray(samples, dtype=np.float32) * 32767.0,
                  -32768, 32767).astype("<i2")
    buf = io.BytesIO()
    with wave.open(buf, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes(pcm.tobytes())
    return Response(content=buf.getvalue(), media_type="audio/wav",
                    headers={"X-Sample-Rate": str(sr)})


if __name__ == "__main__":
    # モデルは起動時にロードしておく(初回リクエストの遅延を避ける)
    _get()
    uvicorn.run(app, host="0.0.0.0", port=int(os.environ.get("PORT", "8082")))
