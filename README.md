# vllm-omni-demo

Serve four modalities through one engine on a single H100 — image, video, speech, and a world model — swapped on the same GPU. The scripts behind my Conf42 LLMs 2026 talk, *How vLLM-Omni Unifies Multimodal Inference*.

📖 **Full walkthrough:** [vLLM-Omni on Nebius H100 — cloudthrill.ca](https://cloudthrill.ca)
🎥 **Talk:** [YouTube](https://www.youtube.com/watch?v=GPTqJzNcEWs)

This repo is the clone-and-run companion. The blog is the narrative; this is the quickstart.

---

## What runs where

| Modality | Model | Port | Endpoint |
|---|---|---|---|
| Image | `Tongyi-MAI/Z-Image-Turbo` | 8091 | `/v1/images/generations` |
| Image → Video | `Wan-AI/Wan2.2-TI2V-5B-Diffusers` | 8091 | `/v1/videos` (async) |
| Speech | `Qwen/Qwen3-TTS-12Hz-1.7B-CustomVoice` | 8091 | `/v1/audio/speech` |
| World model | `nvidia/Cosmos3-Nano` | 8000 | `/v1/videos/sync` |

The first three share `:8091` and get swapped on the GPU. Cosmos runs on its own image (`vllm/vllm-omni:cosmos3`) and port (`:8000`) and wants the whole card.

> **Serve** runs **on the box** (the GPU). **Requests** run **on your laptop**, hitting `localhost` through the SSH tunnel — so output files land locally.

---

## Layout

```
scripts/
  provision.sh        # one-shot Nebius single-H100 box (source it, don't run it)
  box.env             # re-derive INF_VM_ID / INF_IP by name in a fresh shell
  serve_image.sh      # Z-Image    on :8091
  serve_video.sh      # Wan2.2     on :8091  (--cache-backend cache_dit)
  serve_tts.sh        # Qwen3-TTS  on :8091
  serve_cosmos.sh     # Cosmos 3   on :8000  (uses no_guardrails.yaml)
  no_guardrails.yaml  # disables Cosmos's gated guardrail at init
  demo_menu.sh        # skippable menu — fires the right request per modality
  cleanup.sh          # delete VM + disk, stop the meter
requests/
  REQUESTS.md         # standalone curl per model
```

---

## Quickstart

**Prereqs (laptop):** `nebius` CLI authenticated, `jq`, an SSH keypair at `~/.ssh/id_rsa_oci(.pub)`.

```bash
# 1 · provision (SOURCE it — vars must persist)
source scripts/provision.sh

# 2 · connect with the tunnel (forwards both serve ports + the playground UI)
ssh -i ~/.ssh/id_rsa_oci \
  -L 8091:localhost:8091 -L 8000:localhost:8000 -L 8080:localhost:8080 \
  -o ServerAliveInterval=60 -o LogLevel=ERROR user@$INF_IP

# 3 · on the box: enable docker + verify GPU
sudo usermod -aG docker user && newgrp docker
docker run --rm --gpus all nvidia/cuda:12.4.0-base-ubuntu22.04 nvidia-smi

# 4 · copy the scripts up
scp -i ~/.ssh/id_rsa_oci scripts/serve_*.sh scripts/no_guardrails.yaml \
    scripts/demo_menu.sh user@$INF_IP:~/
```

**Serve a model (on the box), then query it (laptop, via tunnel):**

```bash
./serve_image.sh && docker logs -f omni     # wait for the serving line
# ... then from the laptop, hit :8091 — see requests/REQUESTS.md
docker stop omni                            # swap off, frees the GPU
```

Repeat for `serve_video.sh`, `serve_tts.sh`. For Cosmos, stop the `:8091`
container first (it needs the whole GPU), then `./serve_cosmos.sh`.

**Or drive everything from the menu** (servers must already be running):

```bash
./demo_menu.sh      # pick a modality, it prints + times the request
```

**Teardown when done (laptop) — stop the meter:**

```bash
./cleanup.sh        # derives ids by name, deletes instance then disk
```

---

## Gotchas

- **Cosmos 401 at startup** — it pulls a gated guardrail repo at init. `no_guardrails.yaml` disables it server-wide (`guardrails: false` at both top level and inside the stage). Note: `--no-guardrails` is a *Cosmos Framework* flag and is **not** recognized by vLLM-Omni.
- **`docker: name "/omni" already in use`** — a stopped container is squatting the name. The serve scripts already `docker rm -f omni` up front; if you hit it manually, `docker rm -f omni`.
- **Video slower than expected** — almost always cold start. Warm with one throwaway generation; the next run is fast. Cache-DiT is a serve-time flag, not a request param.
- **`$vid` empty / poll never ends** — submit + poll must run in the same shell. Keep them together (the menu and `REQUESTS.md` already do).
- **SSH `channel N: connect failed` spam** — a forwarded port isn't listening yet. Harmless; silenced by `-o LogLevel=ERROR`.

---

Built on open-source [vLLM-Omni](https://github.com/vllm-project/vllm-omni). Hardware: [Nebius](https://nebius.com).
