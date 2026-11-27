#!/bin/sh -ve

# SPDX-FileCopyrightText: 2019-Present Christian Kußowski
# SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
#
# SPDX-License-Identifier: AGPL-3.0-or-later

set -eu
SED=$(command -v gsed || command -v sed)

# Release asset digests recorded from the upstream GitHub release API.
# Updating dependencies requires reviewing and updating these pins.
verify_sha256() {
    expected=$1
    file=$2
    if command -v sha256sum >/dev/null 2>&1; then
        printf '%s  %s\n' "$expected" "$file" | sha256sum -c -
    else
        printf '%s  %s\n' "$expected" "$file" | shasum -a 256 -c -
    fi
}

workdir=$(mktemp -d)
trap 'rm -rf "$workdir"' EXIT HUP INT TERM

# Download prebuilt Vodozemac for web (must match the resolved vodozemac bindings)
version=$(yq ".packages.vodozemac.version" < pubspec.lock)
version=$(printf "%s" "$version" | tr -d '"')
test "$version" = "0.10.0" || { echo "Unreviewed Vodozemac version" >&2; exit 1; }
curl --proto '=https' --proto-redir '=https' -fsSL "https://github.com/famedly/dart-vodozemac/releases/download/v${version}/vodozemac-web.zip" -o "$workdir/vodozemac-web.zip"
verify_sha256 de4a8c2973930429caaa0a6920bbca166199f9da681ed01b3ded0bebfb74100d "$workdir/vodozemac-web.zip"
mkdir -p "./assets/vodozemac/$version/"
unzip -o -q "$workdir/vodozemac-web.zip" 'vodozemac_bindings_dart*' -d "./assets/vodozemac/$version/"
grep -qF "assets/vodozemac/${version}/" pubspec.yaml || "$SED" -i "\|- assets/sounds/|a\\    - assets/vodozemac/${version}/" pubspec.yaml
"$SED" -i "s/vodozemacVersion = '.*';/vodozemacVersion = '${version}';/" lib/config/app_config.dart

flutter pub get
dart compile js ./web/native_executor.dart -o ./web/native_executor.js -m

# Download native_imaging for web (match the resolved lockfile).
version=$(yq ".packages.native_imaging.version" < pubspec.lock)
version=$(printf "%s" "$version" | tr -d '"')
test "$version" = "1.0.0" || { echo "Unreviewed native_imaging version" >&2; exit 1; }
curl --proto '=https' --proto-redir '=https' -fsSL "https://github.com/famedly/dart_native_imaging/releases/download/v${version}/native_imaging.zip" -o "$workdir/native_imaging.zip"
verify_sha256 35a4786bf91c48fc500af724fc6191bd7ecc5a4dc67a7b5e8a1ab745dad4252c "$workdir/native_imaging.zip"
unzip -q "$workdir/native_imaging.zip" -d "$workdir/native_imaging"
cp "$workdir/native_imaging/js/"* web/

# Enable E2EE for LiveKit using the locked package's exact upstream commit.
version=$(yq ".packages.livekit_client.version" < pubspec.lock)
version=$(printf "%s" "$version" | tr -d '"')
test "$version" = "2.13.2" || { echo "Unreviewed LiveKit version" >&2; exit 1; }
livekit_commit=7adc5959f735045261e6a81accb5cb6a9ad79a7b
project_dir=$(pwd)
git init -q "$workdir/livekit"
git -C "$workdir/livekit" remote add origin https://github.com/livekit/client-sdk-flutter.git
git -C "$workdir/livekit" fetch --depth 1 origin "$livekit_commit"
git -C "$workdir/livekit" checkout --detach FETCH_HEAD
test "$(git -C "$workdir/livekit" rev-parse HEAD)" = "$livekit_commit"
cd "$workdir/livekit"
flutter pub get

# Patch so that LiveKit uses HKDF by default:
# Workaroudn for https://github.com/livekit/client-sdk-flutter/issues/974
"$SED" -i "s/{'name': 'PBKDF2'.toJS}/{'name': 'HKDF'.toJS}/g" web/e2ee.keyhandler.dart
"$SED" -i "s/getAlgoOptions('PBKDF2', salt)/getAlgoOptions('HKDF', salt)/g" web/e2ee.keyhandler.dart
"$SED" -i "s/{'name': 'PBKDF2'}/{'name': 'HKDF'}/g"           web/e2ee.utils.dart

dart compile js web/e2ee.worker.dart -o "$project_dir/web/e2ee.worker.dart.js" -m
cd "$project_dir"