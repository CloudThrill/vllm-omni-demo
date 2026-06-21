#!/usr/bin/env bash
# provision.sh — one-shot single-H100 box on Nebius for the vLLM-Omni demo.
#
# IMPORTANT: source this, don't execute it —  the exported vars (INF_IP etc.)
# must persist in your shell so you can SSH afterward:
#     source ./provision.sh
#
# Prereqs: nebius CLI authenticated, jq installed, an SSH keypair at
# ~/.ssh/id_rsa(.pub). Adjust KEY if yours differs.

set -u
KEY=~/.ssh/id_rsa

need() {  # guard: bail (return, not exit — we're sourced) if a var is empty
  if [ -z "${!1:-}" ]; then echo "✗ $1 is empty — stopping."; return 1; fi
}

# 0 · bind tenant + project (index 0 = first of each; change if you have several)
export TENANT_ID=$(nebius iam tenant list --format json | jq -r '.items[0].metadata.id')
need TENANT_ID || return 1
export PROJECT_ID=$(nebius iam project list --parent-id "$TENANT_ID" --format json | jq -r '.items[0].metadata.id')
need PROJECT_ID || return 1
nebius config set parent-id "$PROJECT_ID"
echo "✓ project: $(nebius config get parent-id)"

# 1 · boot disk (CUDA drivers preinstalled)
export INF_VM_BOOT_DISK_ID=$(nebius compute disk create \
  --name inf-disk --size-gibibytes 200 --type network_ssd \
  --source-image-family-image-family ubuntu22.04-cuda12 \
  --block-size-bytes 4096 --format json | jq -r ".metadata.id")
need INF_VM_BOOT_DISK_ID || return 1
echo "✓ disk:    $INF_VM_BOOT_DISK_ID"

# 2 · subnet + cloud-init user (injects your public key)
export SUBNET_ID=$(nebius vpc subnet list --format json | jq -r ".items[0].metadata.id")
need SUBNET_ID || return 1
export USER_DATA=$(jq -Rs '.' <<EOF
users:
  - name: user
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    ssh_authorized_keys:
      - $(cat ${KEY}.pub)
EOF
)

# 3 · create the single-H100 VM
export INF_VM_ID=$(nebius compute instance create --format json - <<EOF | jq -r ".metadata.id"
{ "metadata": { "name": "vllm-omni-demo" },
  "spec": { "stopped": false, "cloud_init_user_data": $USER_DATA,
    "resources": { "platform": "gpu-h100-sxm", "preset": "1gpu-16vcpu-200gb" },
    "boot_disk": { "attach_mode": "READ_WRITE", "existing_disk": { "id": "$INF_VM_BOOT_DISK_ID" } },
    "network_interfaces": [ { "name": "nic0", "subnet_id": "$SUBNET_ID", "ip_address": {}, "public_ip_address": {} } ] } }
EOF
)
need INF_VM_ID || return 1
echo "✓ vm:      $INF_VM_ID"

# 4 · public IP
export INF_IP=$(nebius compute instance get --id "$INF_VM_ID" --format json | jq -r '.status.network_interfaces[0].public_ip_address.address | split("/")[0]')
need INF_IP || return 1
echo "✓ ip:      $INF_IP"

echo
echo "Connect with the tunnel (forwards both serve ports + the playground UI):"
echo "  ssh -i $KEY -L 8091:localhost:8091 -L 8000:localhost:8000 -L 8080:localhost:8080 \\"
echo "      -o ServerAliveInterval=60 -o LogLevel=ERROR user@$INF_IP"
