#!/usr/bin/env bash
# demo_menu.sh — fire the right request for each modality from one menu.
# Servers run separately (you swap them by hand): image/video/speech on :8091,
# Cosmos on :8000. This only sends the requests, prints each curl, and times it.
#
# Run from the dir holding whale.png / f1_dashcam.png (the demo working dir).

cd "$(dirname "$0")" 2>/dev/null
show() { printf '\033[36m$ %s\033[0m\n' "$*"; eval "$@"; }

# ===== IMAGE — Z-Image (:8091) =====
image() {
  start=$SECONDS
  show "curl -s http://localhost:8091/v1/images/generations -H 'Content-Type: application/json' -d '{\"model\":\"Tongyi-MAI/Z-Image-Turbo\",\"prompt\":\"a whale swimming through clouds above a city, surreal, golden hour\",\"negative_prompt\":\"blurry, low quality, deformed\",\"seed\":42,\"num_inference_steps\":6,\"guidance_scale\":1,\"size\":\"1024x1024\",\"n\":1}' | jq -r '.data[0].b64_json' | base64 -d > whale.png"
  e=$((SECONDS-start)); printf '[%02d:%02d] done · ' "$((e/60))" "$((e%60))"; ls -lh whale.png
}

# ===== IMAGE -> VIDEO — Wan2.2 (:8091, submit + poll + download) =====
video() {
  printf '\033[36m$ POST /v1/videos (input_reference=@whale.png) → poll → /content\033[0m\n'
  vid=$(curl -s -X POST http://localhost:8091/v1/videos \
    -F 'model=Wan-AI/Wan2.2-TI2V-5B-Diffusers' -F 'input_reference=@whale.png' \
    -F 'prompt=the whale glides slowly through drifting clouds, gentle camera push-in, cinematic, golden hour' \
    -F 'negative_prompt=blurry, distorted, flicker, warping, morphing, low quality' \
    -F 'seconds=5' -F 'num_inference_steps=50' -F 'guidance_scale=5.0' -F 'flow_shift=5.0' \
    -F 'enable_frame_interpolation=true' -F 'frame_interpolation_exp=2' -F 'seed=100' \
    | jq -r '.id'); echo "job: $vid"
  start=$SECONDS
  while :; do
    s=$(curl -s http://localhost:8091/v1/videos/$vid | jq -r '.status')
    e=$((SECONDS-start)); printf '\r[%02d:%02d] %s        ' "$((e/60))" "$((e%60))" "$s"
    [ "$s" = completed ] && { echo; break; }
    [ "$s" = failed ] && { echo; echo FAILED; curl -s http://localhost:8091/v1/videos/$vid | jq .; return; }
    sleep 5
  done
  curl -s http://localhost:8091/v1/videos/$vid/content -o whale_i2v.mp4 && ls -lh whale_i2v.mp4
}

# ===== SPEECH — Qwen3-TTS (:8091) =====
tts() {
  start=$SECONDS
  show "curl -s -X POST http://localhost:8091/v1/audio/speech -H 'Content-Type: application/json' -d '{\"input\":\"Sight. Sound. Voice. Motion. The new senses of artificial intelligence, with vLLM Omni.\",\"voice\":\"vivian\",\"language\":\"English\",\"max_new_tokens\":4096}' --output tts_demo.wav"
  e=$((SECONDS-start)); printf '[%02d:%02d] done · ' "$((e/60))" "$((e%60))"; ls -lh tts_demo.wav
}

# ===== COSMOS — F1 image->video + SOUND (:8000, sync, bg spinner) =====
cosmos() {
  printf '\033[36m$ POST /v1/videos/sync (input_reference=@f1_dashcam.png, generate_sound=true)\033[0m\n'
  start=$SECONDS
  curl -sS -X POST http://localhost:8000/v1/videos/sync -F "input_reference=@f1_dashcam.png" \
    -F "prompt=A high-speed racing event where a car navigates multiple winding turns" \
    -F "size=1280x720" -F "num_frames=189" -F "fps=24" -F "num_inference_steps=35" \
    -F "guidance_scale=6.0" -F "flow_shift=10.0" -F "seed=0" -F "generate_sound=true" \
    --form-string 'extra_params={"use_resolution_template":false,"use_duration_template":false}' \
    -o cosmos3_f1.mp4 &
  pid=$!
  while kill -0 $pid 2>/dev/null; do
    e=$((SECONDS-start)); printf '\r[%02d:%02d] generating…   ' "$((e/60))" "$((e%60))"; sleep 1
  done
  e=$((SECONDS-start)); printf '\r[%02d:%02d] done           \n' "$((e/60))" "$((e%60))"; ls -lh cosmos3_f1.mp4
}

PS3=$'\n>>> pick a step, or 5 to quit: '
while true; do
  echo
  select choice in "IMAGE (Z-Image)" "VIDEO (Wan2.2 i2v)" "SPEECH (Qwen3-TTS)" "COSMOS (F1 i2v+sound :8000)" "quit"; do
    case $REPLY in
      1) image; break ;;
      2) video; break ;;
      3) tts; break ;;
      4) cosmos; break ;;
      5) exit 0 ;;
      *) echo "pick 1-5"; break ;;
    esac
  done
done
