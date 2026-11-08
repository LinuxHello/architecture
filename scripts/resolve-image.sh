#!/usr/bin/env bash
# Pull the pinned Structurizr image and print the reference that worked, for example
#   image="$(scripts/resolve-image.sh podman)"
#
# Tries the organisation's registry first, then Docker Hub. Both references carry the same digest
# (scripts/image.env), so the engine refuses anything else. Progress goes to stderr; the reference
# alone goes to stdout. Exits 1 if neither registry delivers it.
set -euo pipefail
engine="${1:?usage: resolve-image.sh docker|podman}"
env_file="${LH_IMAGE_ENV:-$(dirname "${BASH_SOURCE[0]}")/image.env}"
# shellcheck source=scripts/image.env
source "$env_file"

for repo in "$STRUCTURIZR_MIRROR" "$STRUCTURIZR_UPSTREAM"; do
  ref="$repo@$STRUCTURIZR_DIGEST"
  if "$engine" pull --quiet "$ref" >/dev/null 2>&1; then
    echo "image: $ref" >&2
    printf '%s\n' "$ref"
    exit 0
  fi
  echo "could not pull $ref" >&2
done
echo "the Structurizr image is available from neither registry" >&2
exit 1
