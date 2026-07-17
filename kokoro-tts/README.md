# kokoro-tts

Kokoro-82M による TTS API サーバー(OpenAI speech API 互換 / CPU推論)。
rocm-ai-docker スタックの1サービスとして start_ai.sh から起動される(port 8082)。

## セットアップ(コンテナ内で1回)
```
cd ~/share/kokoro-tts
python3 -m venv venv
venv/bin/pip install -r requirements.txt
```
モデル(約350MB)は初回起動時に models/ へ自動DL。

## 使い方
```
curl -X POST http://evo-x2.local:8082/v1/audio/speech \
  -H "Content-Type: application/json" \
  -d '{"input": "Hello, this is a test.", "voice": "af_bella", "speed": 1.0}' \
  -o out.wav
```
- 声一覧: `GET /v1/voices` / ヘルスチェック: `GET /health`
- 出力: 24kHz mono 16bit WAV
- english-radio の factory は `TTS_ENGINE=kokoro_remote` + `KOKORO_TTS_URL` でこれを利用可能(evo-x2不達時はローカルKokoroへ自動フォールバック)
