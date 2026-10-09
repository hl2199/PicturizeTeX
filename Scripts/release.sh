#!/bin/bash
# Builds a release and zips it for a GitHub Release.
#   Scripts/release.sh 1.0.0  ->  build/PicturizeTeX-1.0.0.zip
set -euo pipefail

VERSION="${1:?usage: release.sh <version>}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

VERSION="$VERSION" "$ROOT/Scripts/bundle.sh" release

ZIP="$ROOT/build/PicturizeTeX-$VERSION.zip"
rm -f "$ZIP"
# ditto preserves the bundle structure, resource forks, and the signature.
ditto -c -k --keepParent "$ROOT/build/PicturizeTeX.app" "$ZIP"
echo "$ZIP"
