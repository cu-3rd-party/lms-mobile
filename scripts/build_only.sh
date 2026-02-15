#!/usr/bin/env bash
# Только билд Android + iOS, переименование и копирование в release/.
# Без бампа версии, коммита и тега.

set -euo pipefail

flutter pub get
flutter build apk --release
flutter build ipa --release --no-codesign

# С --no-codesign Flutter кладёт только xcarchive, .app внутри него
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

echo "Done. Artifacts in $release_dir/: app-release.apk, app-release.ipa"
