#!/usr/bin/env bash
# Z-Image-Turbo — image generation on :8091
docker stop omni 2>/dev/null; docker rm -f omni 2>/dev/null
docker run -d --rm --name omni --gpus all -p 8091:8091 --ipc=host \
  -v ~/.cache/huggingface:/root/.cache/huggingface \
  vllm/vllm-omni:v0.22.0 vllm serve Tongyi-MAI/Z-Image-Turbo --omni --port 8091
echo "starting Z-Image... watch: docker logs -f omni"
