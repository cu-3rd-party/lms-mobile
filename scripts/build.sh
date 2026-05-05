#!/usr/bin/env bash

set -euo pipefail

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  cat <<'EOF'
Использование: scripts/build.sh [major|minor|patch] [--push]

Без аргументов:    собирает APK + неподписанный IPA в release/.
С бампом версии:   поднимает версию в pubspec (от последнего тега vX.Y.Z),
                   делает коммит + git-тег, и дополнительно собирает AAB
                   и подписанный IPA (открывает .xcarchive для загрузки
                   в App Store / TestFlight).

Опции:
  --push   Запушить коммит и тег в origin (имеет смысл только с бампом).
EOF
  exit 0
fi

bump=""
push_flag="false"
for arg in "$@"; do
  case "$arg" in
    major|minor|patch) bump="$arg" ;;
    --push) push_flag="true" ;;
    -h|--help) ;;
    *) echo "Неизвестный аргумент: $arg" >&2; exit 1 ;;
  esac
done

is_release="false"
[[ -n "$bump" ]] && is_release="true"

if [[ "$push_flag" == "true" && "$is_release" != "true" ]]; then
  echo "--push требует аргумент бампа (major|minor|patch)" >&2
  exit 1
fi

if [[ "$is_release" == "true" ]]; then
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
    major) major=$((major + 1)); minor=0; patch=0 ;;
    minor) minor=$((minor + 1)); patch=0 ;;
    patch) patch=$((patch + 1)) ;;
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
    raise SystemExit("Не удалось обновить версию в pubspec.yaml")
path.write_text(updated)
Path(version_file).write_text(f"{new_version}\n{new_full_version}\n")
PY

  { read -r new_version; read -r new_full_version; } < "$version_file"
  echo "Версия обновлена до ${new_full_version} (от ${latest_tag}, bump=${bump})"

  if [[ -n "$(git status --porcelain)" ]]; then
    git add pubspec.yaml
    git commit -m "chore: bump version to ${new_version}"
  fi

  git tag "v${new_version}"

  if [[ "$push_flag" == "true" ]]; then
    git push origin HEAD
    git push origin "v${new_version}"
  fi
fi

flutter pub get

flutter build apk --release
flutter build ipa --release --no-codesign

if [[ "$is_release" == "true" ]]; then
  flutter build appbundle --release
fi

rm -rf Payload
mkdir -p Payload
runner_app="build/ios/archive/Runner.xcarchive/Products/Applications/Runner.app"
if [[ -d "$runner_app" ]]; then
  cp -R "$runner_app" Payload/
else
  cp -R build/ios/iphoneos/Runner.app Payload/
fi
(cd Payload/.. && zip -r Runner-unsigned.ipa Payload)

release_dir="release"
mkdir -p "$release_dir"
cp -f build/app/outputs/flutter-apk/app-release.apk "$release_dir/app-release.apk"
cp -f Runner-unsigned.ipa "$release_dir/app-release.ipa"

if [[ "$is_release" == "true" ]]; then
  cp -f build/app/outputs/bundle/release/app-release.aab "$release_dir/app-release.aab"

  flutter build ipa --release --export-method app-store
  open build/ios/archive/Runner.xcarchive
  echo "Подписанный xcarchive открыт — Distribute App → App Store Connect → Upload."
fi

echo "Готово. Артефакты в $release_dir/"
