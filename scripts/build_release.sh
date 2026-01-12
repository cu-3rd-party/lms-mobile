#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  cat <<'EOF'
Usage: scripts/build_release.sh [major|minor|patch] [--push]

Bumps pubspec.yaml version based on the latest git tag (vX.Y.Z), commits,
creates a tag, and builds:
  - Android APK (release)
  - iOS IPA (release, no codesign)

Options:
  --push   Push commit and tag to origin
EOF
  exit 0
fi

bump="${1:-patch}"
push_flag="false"
for arg in "$@"; do
  if [[ "$arg" == "--push" ]]; then
    push_flag="true"
  fi
done
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

if [[ -n "$(git status --porcelain)" ]]; then
  git add pubspec.yaml
  git commit -m "chore: bump version to ${new_version}"
fi

git tag "v${new_version}"

if [[ "$push_flag" == "true" ]]; then
  git push origin HEAD
  git push origin "v${new_version}"
fi

flutter pub get
flutter build apk --release
flutter build ipa --release --no-codesign

rm -rf Payload
mkdir -p Payload
cp -R build/ios/iphoneos/Runner.app Payload/

(cd Payload/.. && zip -r Runner-unsigned.ipa Payload)

release_dir="release"
mkdir -p "$release_dir"
cp -f build/app/outputs/flutter-apk/app-release.apk "$release_dir/app-release.apk"
cp -f Runner-unsigned.ipa "$release_dir/app-release.ipa"
