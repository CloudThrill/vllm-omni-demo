# Standalone requests

One `curl` per modality, for hitting each server directly. Run from a dir with
`whale.png` / `f1_dashcam.png` as needed. Image/video/speech → `:8091`, Cosmos → `:8000`.

## Image — Z-Image (`POST /v1/images/generations`, sync, JSON)

Response is base64 in `data[0].b64_json` — decode to a PNG.

```bash
curl -s http://localhost:8091/v1/images/generations \
  -H "Content-Type: application/json" \
  -d '{
    "model":"Tongyi-MAI/Z-Image-Turbo",
    "prompt":"a whale swimming through clouds above a city, surreal, golden hour",
    "negative_prompt":"blurry, low quality, deformed, distorted, washed out, artifacts",
    "seed":42, "num_inference_steps":6, "guidance_scale":1, "size":"1024x1024", "n":1
  }' | jq -r '.data[0].b64_json' | base64 -d > whale.png
```

## Image → Video — Wan2.2 (`POST /v1/videos`, async: submit → poll → download)

`input_reference=@file` must use `-F` (the `@` uploads the file).

```bash
vid=$(curl -s -X POST http://localhost:8091/v1/videos \
  -F 'model=Wan-AI/Wan2.2-TI2V-5B-Diffusers' -F 'input_reference=@whale.png' \
  -F 'prompt=the whale glides slowly through drifting clouds, gentle camera push-in, cinematic, golden hour' \
  -F 'seconds=5' -F 'num_inference_steps=50' -F 'guidance_scale=5.0' -F 'flow_shift=5.0' \
  -F 'enable_frame_interpolation=true' -F 'frame_interpolation_exp=2' -F 'seed=100' \
  | jq -r '.id')

# poll until completed, then download
while [ "$(curl -s http://localhost:8091/v1/videos/$vid | jq -r .status)" != completed ]; do sleep 5; done
curl -s http://localhost:8091/v1/videos/$vid/content -o whale_i2v.mp4
```

## Speech — Qwen3-TTS (`POST /v1/audio/speech`, sync, JSON)

Response **body is the audio** — no base64, no polling.

```bash
curl -s -X POST http://localhost:8091/v1/audio/speech \
  -H "Content-Type: application/json" \
  -d '{"input":"Sight. Sound. Voice. Motion. The new senses of artificial intelligence, with vLLM Omni.","voice":"vivian","language":"English","max_new_tokens":4096}' \
  --output tts_demo.wav
```

## World model — Cosmos 3 (`POST /v1/videos/sync`, sync, multipart)

Synchronous — body is the MP4. `generate_sound=true` muxes audio in.

```bash
curl -sS -X POST http://localhost:8000/v1/videos/sync \
  -F "input_reference=@f1_dashcam.png" \
  -F "prompt=A high-speed racing event where a car navigates multiple winding turns" \
  -F "size=1280x720" -F "num_frames=189" -F "fps=24" -F "num_inference_steps=35" \
  -F "guidance_scale=6.0" -F "flow_shift=10.0" -F "seed=0" -F "generate_sound=true" \
  --form-string 'extra_params={"use_resolution_template":false,"use_duration_template":false}' \
  -o cosmos3_f1.mp4
```
