#!/usr/bin/env bash
# Render every C4 view of workspace.dsl to diagrams/*.svg with Structurizr and headless Chrome.
#
#   scripts/render-diagrams.sh            render into diagrams/ (run after changing workspace.dsl)
#   scripts/render-diagrams.sh --check    render to a temporary directory and fail when the words
#                                         of an image differ from the committed one (CI uses this)
#   --out DIR                             keep the rendered files in DIR (CI uploads them on failure)
#
# Needs: docker or podman, node, npm, and Chrome (CHROME_BIN, or google-chrome/chromium on PATH).
# Structurizr runs in a container from a pinned image on a scratch copy of workspace.dsl, so it
# cannot write into this repository.
set -euo pipefail

# structurizr/structurizr v2026.09.19, pinned by digest.
IMAGE="docker.io/structurizr/structurizr@sha256:4cadb3a52ba0dcca28e31ee0d68325d13bc27a90e067b6b793089eab0fa7dfac"

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
mode=render
out=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --check) mode=check ;;
    --out) out="${2:?--out needs a directory}"; shift ;;
    -h|--help) sed -n '2,12p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
  shift
done

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing prerequisite: $1 ($2)" >&2; exit 1; }; }
engine=""
for e in docker podman; do command -v "$e" >/dev/null 2>&1 && { engine="$e"; break; }; done
[[ -n "$engine" ]] || { echo "missing prerequisite: docker or podman (runs Structurizr)" >&2; exit 1; }
need node "renders with Playwright"
need npm "installs playwright-core from scripts/render/package-lock.json"
if [[ -z "${CHROME_BIN:-}" ]]; then
  for c in google-chrome chromium chromium-browser; do command -v "$c" >/dev/null 2>&1 && { CHROME_BIN="$(command -v "$c")"; break; }; done
fi
[[ -n "${CHROME_BIN:-}" ]] || { echo "missing prerequisite: Chrome (set CHROME_BIN or put google-chrome or chromium on PATH)" >&2; exit 1; }
export CHROME_BIN

work="$(mktemp -d)"
name="structurizr-render-$$"
cleanup() { "$engine" rm -f "$name" >/dev/null 2>&1 || true; rm -rf "$work"; }
trap cleanup EXIT

[[ -d "$root/scripts/render/node_modules/playwright-core" ]] || npm ci --ignore-scripts --no-audit --no-fund --prefix "$root/scripts/render"

mkdir -p "$work/ws"
cp "$root/workspace.dsl" "$work/ws/workspace.dsl"
chmod -R a+rwX "$work/ws"
# Run as the calling user so the files Structurizr writes into the scratch copy can be removed.
# Rootless podman needs keep-id for that; docker maps the ids directly.
user_args=(--user "$(id -u):$(id -g)")
[[ "$engine" = podman ]] && user_args+=(--userns=keep-id)
"$engine" run -d --rm --name "$name" "${user_args[@]}" -p 127.0.0.1::8080 -v "$work/ws:/usr/local/structurizr:Z" "$IMAGE" local >/dev/null
hostport="$("$engine" port "$name" 8080/tcp | head -n1)"
base="http://127.0.0.1:${hostport##*:}"

for _ in $(seq 1 60); do
  [[ "$(curl -s -o /dev/null -w '%{http_code}' "$base/workspace/1" || true)" = 200 ]] && break
  sleep 1
done
[[ "$(curl -s -o /dev/null -w '%{http_code}' "$base/workspace/1" || true)" = 200 ]] || { echo "Structurizr did not come up at $base" >&2; "$engine" logs "$name" 2>&1 | tail -20 >&2; exit 1; }

rendered="${out:-$work/rendered}"
rm -rf "$rendered"
node "$root/scripts/render/render.mjs" "$base" "$rendered"

if [[ "$mode" = check ]]; then
  node "$root/scripts/render/compare.mjs" "$root/diagrams" "$rendered"
  echo "diagrams/ matches workspace.dsl"
else
  mkdir -p "$root/diagrams"
  find "$root/diagrams" -maxdepth 1 -name '*.svg' -delete
  cp "$rendered"/*.svg "$root/diagrams/"
  echo "wrote $(ls "$root/diagrams"/*.svg | wc -l) files to diagrams/"
fi
