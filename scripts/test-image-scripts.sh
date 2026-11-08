#!/usr/bin/env bash
# Tests for scripts/resolve-image.sh and scripts/mirror-image.sh with stub engines: no network, no
# registry. The scripts must prefer the mirror, fall back to Docker Hub with the same digest, copy
# only when needed and with the digest preserved, and refuse a copy that has another digest.
#
#   scripts/test-image-scripts.sh
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
work="$(mktemp -d)"; trap 'rm -rf "$work"' EXIT
pass=0 fail=0
ok()  { pass=$((pass + 1)); echo "ok   $1"; }
nok() { fail=$((fail + 1)); echo "FAIL $1: $2"; }

# A manifest whose digest we know, and an image.env that pins it.
printf 'manifest-bytes' > "$work/manifest"
digest="sha256:$(sha256sum "$work/manifest" | cut -d' ' -f1)"
cat > "$work/image.env" <<ENV
STRUCTURIZR_DIGEST=$digest
STRUCTURIZR_UPSTREAM=hub.example/structurizr
STRUCTURIZR_MIRROR=ghcr.example/org/structurizr
STRUCTURIZR_TAG=v1
ENV
export LH_IMAGE_ENV="$work/image.env"
mkdir -p "$work/bin"; export PATH="$work/bin:$PATH"

# --- resolve-image.sh with a stub engine: FAKE_PULL_OK lists the registries that deliver.
cat > "$work/bin/fakeengine" <<'STUB'
#!/usr/bin/env bash
[[ "$1" == pull ]] || exit 2
ref="${@: -1}"
for ok in $FAKE_PULL_OK; do [[ "$ref" == "$ok"* ]] && exit 0; done
exit 1
STUB
chmod +x "$work/bin/fakeengine"
resolve() { FAKE_PULL_OK="$1" bash "$here/resolve-image.sh" fakeengine 2>/dev/null; }

got=$(resolve "ghcr.example hub.example") || true
[[ "$got" == "ghcr.example/org/structurizr@$digest" ]] && ok the_mirror_is_preferred || nok the_mirror_is_preferred "got [$got]"
got=$(resolve "hub.example") || true
[[ "$got" == "hub.example/structurizr@$digest" ]] && ok docker_hub_is_the_fallback_with_the_same_digest || nok docker_hub_is_the_fallback_with_the_same_digest "got [$got]"
rc=0; resolve "" >/dev/null || rc=$?
[[ $rc -eq 1 ]] && ok neither_registry_is_an_error || nok neither_registry_is_an_error "exit $rc"

# --- mirror-image.sh with a stub skopeo that logs its calls. The destination serves FAKE_DEST_MANIFEST
# for `inspect --raw` ("" = nothing there yet) until a `copy` stores FAKE_COPIED_MANIFEST there.
cat > "$work/bin/skopeo" <<'STUB'
#!/usr/bin/env bash
echo "$*" >> "$FAKE_LOG"
case "$1" in
  inspect)
    if [[ -s "$FAKE_STATE" ]]; then cat "$FAKE_STATE"
    elif [[ -n "${FAKE_DEST_MANIFEST:-}" ]]; then printf '%s' "$FAKE_DEST_MANIFEST"; fi ;;
  copy) printf '%s' "${FAKE_COPIED_MANIFEST:-}" > "$FAKE_STATE" ;;
esac
STUB
chmod +x "$work/bin/skopeo"
export FAKE_LOG="$work/log" FAKE_STATE="$work/state"
mirror() { : > "$FAKE_LOG"; rm -f "$FAKE_STATE"; bash "$here/mirror-image.sh" 2>&1; }

out=$(FAKE_DEST_MANIFEST=manifest-bytes mirror) && rc=0 || rc=$?
if [[ $rc -eq 0 && "$out" == *"already mirrored"* ]] && ! grep -q '^copy' "$FAKE_LOG"; then ok an_existing_copy_is_left_alone
else nok an_existing_copy_is_left_alone "exit $rc: $out"; fi

out=$(FAKE_COPIED_MANIFEST=manifest-bytes mirror) && rc=0 || rc=$?
if [[ $rc -eq 0 && "$out" == *"mirrored:"* ]] && grep -q '^copy --all --preserve-digests docker://hub.example/structurizr@'"$digest"' docker://ghcr.example/org/structurizr:v1$' "$FAKE_LOG"; then
  ok a_missing_copy_is_made_for_all_platforms_with_the_digest_preserved
else nok a_missing_copy_is_made_for_all_platforms_with_the_digest_preserved "exit $rc: $out; $(cat "$FAKE_LOG")"; fi

out=$(FAKE_COPIED_MANIFEST=tampered mirror) && rc=0 || rc=$?
[[ $rc -ne 0 && "$out" == *"not the pinned image"* ]] && ok a_copy_with_another_digest_is_refused || nok a_copy_with_another_digest_is_refused "exit $rc: $out"

mkdir -p "$work/emptybin"
rc=0; out=$(PATH="$work/emptybin" "$(command -v bash)" "$here/mirror-image.sh" 2>&1) || rc=$?
[[ $rc -ne 0 && "$out" == *"skopeo is not installed"* ]] && ok a_missing_skopeo_is_said_plainly || nok a_missing_skopeo_is_said_plainly "exit $rc: $out"

echo "$pass passed, $fail failed"
[[ $fail -eq 0 ]]
