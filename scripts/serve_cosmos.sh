#!/usr/bin/env bash
# NVIDIA Cosmos 3 — world model on :8000  (own image, own port, whole GPU)
# Guardrails disabled via deploy-config (gated repo would 401 at init otherwise).
docker stop omni   2>/dev/null; docker rm -f omni   2>/dev/null
docker stop cosmos 2>/dev/null; docker rm -f cosmos 2>/dev/null
docker run -d --rm --name cosmos --runtime nvidia --gpus all --ipc=host -p 8000:8000 \
  -v ~/.cache/huggingface:/root/.cache/huggingface -v "$(pwd):/workspace" \
  vllm/vllm-omni:cosmos3 vllm serve nvidia/Cosmos3-Nano --omni \
  --model-class-name Cosmos3OmniDiffusersPipeline \
  --deploy-config /workspace/no_guardrails.yaml \
  --allowed-local-media-path / --port 8000 --init-timeout 1800
echo "starting Cosmos 3... watch: docker logs -f cosmos  (wait for 'Application startup complete.')"
