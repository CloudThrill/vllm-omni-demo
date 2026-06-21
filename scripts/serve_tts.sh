#!/usr/bin/env bash
# Qwen3-TTS — speech on :8091
docker stop omni 2>/dev/null; docker rm -f omni 2>/dev/null
docker run -d --rm --name omni --gpus all -p 8091:8091 --ipc=host \
  -v ~/.cache/huggingface:/root/.cache/huggingface \
  vllm/vllm-omni:v0.22.0 vllm serve Qwen/Qwen3-TTS-12Hz-1.7B-CustomVoice \
  --deploy-config vllm_omni/deploy/qwen3_tts.yaml --omni --port 8091 \
  --trust-remote-code --enforce-eager --gpu-memory-utilization 0.3
echo "starting Qwen3-TTS... watch: docker logs -f omni"
