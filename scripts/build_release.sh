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
version_file="$(mktemp)"
trap 'rm -f "$version_file"' EXIT

python3 - "$version_file" "${new_version}" "${new_full_version}" "${bump}" "${build_number}" <<'PY'
import re
import sys
from pathlib import Path

path = Path("pubspec.yaml")
data = path.read_text()
_, version_file, tag_version, tag_full, bump, build_number = sys.argv
new_version = tag_version
new_full_version = tag_full

# Get current version from pubspec (e.g. "1.0.2+74" -> ("1.0.2", "74"))
match = re.search(r"^version:\s*(\d+\.\d+\.\d+)(?:\+(\d+))?", data, flags=re.MULTILINE)
if match:
    cur_ver = match.group(1)
    cur_parts = [int(x) for x in cur_ver.split(".")]
    new_parts = [int(x) for x in tag_version.split(".")]
    if cur_parts >= new_parts:
        # Bump from pubspec (e.g. after rollback when pubspec is ahead of tag)
        if bump == "major":
            new_version = f"{cur_parts[0]+1}.0.0"
        elif bump == "minor":
            new_version = f"{cur_parts[0]}.{cur_parts[1]+1}.0"
        else:
            new_version = f"{cur_parts[0]}.{cur_parts[1]}.{cur_parts[2]+1}"
        new_full_version = new_version + "+" + build_number
    else:
        new_version = tag_version
        new_full_version = tag_full
else:
    new_version = tag_version
    new_full_version = tag_full

updated = re.sub(r"^version:\s*.+$", f"version: {new_full_version}", data, flags=re.MULTILINE)
if data == updated:
    raise SystemExit("Failed to update version in pubspec.yaml")
path.write_text(updated)
Path(version_file).write_text(f"{new_version}\n{new_full_version}\n")
PY

{ read -r new_version; read -r new_full_version; } < "$version_file"
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
cp -R build/ios/archive/Runner.xcarchive/Products/Applications/Runner.app Payload/

(cd Payload/.. && zip -r Runner-unsigned.ipa Payload)

release_dir="release"
mkdir -p "$release_dir"
cp -f build/app/outputs/flutter-apk/app-release.apk "$release_dir/app-release.apk"
cp -f Runner-unsigned.ipa "$release_dir/app-release.ipa"
