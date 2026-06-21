#!/usr/bin/env bash
# Wan2.2-TI2V — image->video on :8091  (Cache-DiT is a serve-time flag)
docker stop omni 2>/dev/null; docker rm -f omni 2>/dev/null
docker run -d --rm --name omni --gpus all -p 8091:8091 --ipc=host \
  -v ~/.cache/huggingface:/root/.cache/huggingface \
  vllm/vllm-omni:v0.22.0 vllm serve Wan-AI/Wan2.2-TI2V-5B-Diffusers \
  --omni --port 8091 --cache-backend cache_dit
echo "starting Wan2.2... watch: docker logs -f omni"
