#!/usr/bin/env bash
# Copy the pinned Structurizr image from Docker Hub to the organisation's registry, keeping its
# digest, and check the copy. Idempotent: does nothing if the copy is already there.
#
#   scripts/mirror-image.sh        needs skopeo and a login to the destination registry
#
# Run by .github/workflows/mirror-images.yml with the job's own token; it never handles a
# credential itself. The copy is by manifest, all platforms (--all), unchanged
# (--preserve-digests), so the destination digest equals the pinned one or the script fails.
set -euo pipefail
env_file="${LH_IMAGE_ENV:-$(dirname "${BASH_SOURCE[0]}")/image.env}"
# shellcheck source=scripts/image.env
source "$env_file"
command -v skopeo >/dev/null 2>&1 || { echo "skopeo is not installed (sudo apt install skopeo)" >&2; exit 1; }

source_ref="docker://$STRUCTURIZR_UPSTREAM@$STRUCTURIZR_DIGEST"
dest_tag="docker://$STRUCTURIZR_MIRROR:$STRUCTURIZR_TAG"
dest_digest="docker://$STRUCTURIZR_MIRROR@$STRUCTURIZR_DIGEST"

# The digest of a manifest is the SHA-256 of its bytes.
digest_of() { skopeo inspect --raw "$1" 2>/dev/null | sha256sum | sed 's/^/sha256:/; s/ .*//'; }

if [[ "$(digest_of "$dest_digest")" == "$STRUCTURIZR_DIGEST" ]]; then
  echo "already mirrored: $STRUCTURIZR_MIRROR@$STRUCTURIZR_DIGEST"
  exit 0
fi

echo "copying $STRUCTURIZR_UPSTREAM@$STRUCTURIZR_DIGEST to $STRUCTURIZR_MIRROR:$STRUCTURIZR_TAG"
skopeo copy --all --preserve-digests "$source_ref" "$dest_tag"

got="$(digest_of "$dest_tag")"
if [[ "$got" != "$STRUCTURIZR_DIGEST" ]]; then
  echo "the copy has digest ${got:-none}, not $STRUCTURIZR_DIGEST; it is not the pinned image" >&2
  exit 1
fi
echo "mirrored: $STRUCTURIZR_MIRROR@$STRUCTURIZR_DIGEST"
