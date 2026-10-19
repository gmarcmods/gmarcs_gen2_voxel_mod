#!/usr/bin/env bash
# Local release: pack the mod into an installable .zip (no GitHub cloud).
# Uses scripts/export-mods.py, which materializes the voxel_mod symlinks.
# Usage: ./tools/release.sh [X.Y.Z]
set -euo pipefail
MOD_DIR="$(cd "$(dirname "$0")/.." && pwd)"
WORKSPACE_ROOT="$(cd "$MOD_DIR/../../.." && pwd)"
GEN1RECOMP="$WORKSPACE_ROOT/gen1recomp"
cd "$MOD_DIR"

MOD_ID="gmarcs_gen2_voxel_mod"
VERSION="${1:-}"

if [ -z "$VERSION" ]; then
  OVERRIDE=$(git log -1 --pretty=%B | grep -oE '\[release [0-9]+\.[0-9]+\.[0-9]+\]' | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || true)
  if [ -n "$OVERRIDE" ]; then
    VERSION="$OVERRIDE"
  else
    MANIFEST_VERSION=$(python3 -c "import json;print(json.load(open('manifest.json'))['version'])")
    if [[ "$MANIFEST_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
      VERSION="$MANIFEST_VERSION"
    else
      LATEST=$(git tag -l 'v*' --sort=-v:refname | head -1 | sed 's/^v//')
      if [ -n "$LATEST" ]; then
        IFS=. read -r maj min pat <<<"$LATEST"
        pat=$((pat+1)); [ "$pat" -gt 99 ] && { min=$((min+1)); pat=0; }
        VERSION="$maj.$min.$pat"
      else
        VERSION="0.1.0"
      fi
    fi
  fi
fi
TAG="v$VERSION"
echo "Releasing $VERSION (tag $TAG)"

if git rev-parse -q --verify "refs/tags/$TAG" >/dev/null 2>&1; then
  echo "error: tag $TAG already exists" >&2; exit 1
fi

# stamp version into manifest.json
python3 - "$MOD_DIR/manifest.json" "$VERSION" <<'PY'
import json, sys
path, version = sys.argv[1], sys.argv[2]
with open(path, encoding="utf-8") as fh:
    manifest = json.load(fh)
manifest["version"] = version
with open(path, "w", encoding="utf-8") as fh:
    json.dump(manifest, fh, indent=2, ensure_ascii=False)
    fh.write("\n")
PY
git add manifest.json && git commit -m "release: $VERSION" --quiet 2>/dev/null || true

# build via export-mods.py (materializes symlinks, validates)
cd "$WORKSPACE_ROOT"
python3 scripts/export-mods.py "$MOD_ID" 2>&1 | tail -3
ZIP_PATH="$WORKSPACE_ROOT/exports/gen2/${MOD_ID}.zip"
# export-mods lowercases the id for filename
ZIP_PATH2="$WORKSPACE_ROOT/exports/gen2/$(echo $MOD_ID | tr '[:upper:]' '[:lower:]').zip"
[ -f "$ZIP_PATH2" ] && ZIP_PATH="$ZIP_PATH2"
echo "Zip: $ZIP_PATH"

# verify manifest at top-level folder reports correct version
python3 - "$ZIP_PATH" "$VERSION" "$MOD_ID" <<'PY'
import json, sys, zipfile
with zipfile.ZipFile(sys.argv[1]) as z:
    names = [n for n in z.namelist() if n.endswith('manifest.json')]
    assert names, "no manifest.json in zip"
    with z.open(names[0]) as f:
        v = json.load(f)["version"]
if v != sys.argv[2]:
    raise SystemExit(f"packed manifest says {v}, expected {sys.argv[2]}")
print(f"manifest.json reports {v}; top folder: {names[0].split('/')[0]}")
PY

(cd "$(dirname "$ZIP_PATH")" && sha256sum "$(basename "$ZIP_PATH")" > sha256sums.txt)
cat "$(dirname "$ZIP_PATH")/sha256sums.txt"

git -C "$MOD_DIR" tag "$TAG"
echo "Tagged $TAG. Zip: $ZIP_PATH"
