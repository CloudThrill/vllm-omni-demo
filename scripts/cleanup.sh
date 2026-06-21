#!/usr/bin/env bash
# cleanup.sh — tear down the demo box so the meter stops.
# Run from your LAPTOP (not the box). Derives ids by name; deletes instance then disk.
#
#     ./cleanup.sh
#
# This is irreversible. Make sure you've pulled any generated files off the box first.

set -euo pipefail

echo "Resolving vllm-omni-demo ..."
INF_VM_ID=$(nebius compute instance list --format json \
  | jq -r '.items[] | select(.metadata.name=="vllm-omni-demo") | .metadata.id')

if [ -z "$INF_VM_ID" ] || [ "$INF_VM_ID" = "null" ]; then
  echo "No instance named vllm-omni-demo found — nothing to delete."
  exit 0
fi

# read the boot disk id FROM the instance before we delete it
INF_DISK_ID=$(nebius compute instance get --id "$INF_VM_ID" --format json \
  | jq -r '.spec.boot_disk.existing_disk.id')

echo "  VM:   $INF_VM_ID"
echo "  disk: $INF_DISK_ID"
read -rp "Delete both? [y/N] " ans
[ "$ans" = "y" ] || { echo "Aborted."; exit 0; }

# instance first (can't delete an attached disk), then the disk
nebius compute instance delete --id "$INF_VM_ID"
nebius compute disk delete --id "$INF_DISK_ID"

echo
echo "Verifying (both lists empty = billing stopped):"
nebius compute instance list
nebius compute disk list
