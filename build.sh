#!/bin/bash
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"

echo "🔨 Compilation..."

swiftc "${DIR}/src/PKarchives.swift" \
  -parse-as-library \
  -o PKarchives \
  -framework SwiftUI \
  -framework AppKit

cp PKarchives "${DIR}/release/PKarchives.app/Contents/MacOS/"
cp "${DIR}/src/archive.sh" "${DIR}/release/PKarchives.app/Contents/MacOS/"
chmod +x "${DIR}/release/PKarchives.app/Contents/MacOS/"*

rm -f PKarchives
echo "✅ ${DIR}/release/PKarchives.app"
