#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  cat <<'EOF'
Usage: scripts/build_release.sh [major|minor|patch]

Bumps pubspec.yaml version based on the latest git tag (vX.Y.Z) and builds:
  - Android APK (release)
  - iOS IPA (release, no codesign)
EOF
  exit 0
fi

bump="${1:-patch}"
if [[ "$bump" != "major" && "$bump" != "minor" && "$bump" != "patch" ]]; then
  echo "Unknown bump type: $bump (use major|minor|patch)" >&2
  exit 1
fi

latest_tag="$(git tag --list 'v*' --sort=-v:refname | head -n1 || true)"
if [[ -z "$latest_tag" ]]; then
  latest_tag="v0.0.0"
fi

base_version="${latest_tag#v}"
IFS='.' read -r major minor patch_rest <<<"$base_version"
patch="${patch_rest%%[-+]*}"

major="${major:-0}"
minor="${minor:-0}"
patch="${patch:-0}"

case "$bump" in
  major)
    major=$((major + 1))
    minor=0
    patch=0
    ;;
  minor)
    minor=$((minor + 1))
    patch=0
    ;;
  patch)
    patch=$((patch + 1))
    ;;
esac

new_version="${major}.${minor}.${patch}"
build_number="$(git rev-list --count HEAD)"
new_full_version="${new_version}+${build_number}"

python3 - <<PY
import re
from pathlib import Path

path = Path("pubspec.yaml")
data = path.read_text()
new_version = "${new_full_version}"
updated = re.sub(r"^version:\\s*.+$", f"version: {new_version}", data, flags=re.MULTILINE)
if data == updated:
    raise SystemExit("Failed to update version in pubspec.yaml")
path.write_text(updated)
PY

echo "Updated version to ${new_full_version} (from ${latest_tag}, bump=${bump})"

flutter pub get
flutter build apk --release
flutter build ipa --release --no-codesign
