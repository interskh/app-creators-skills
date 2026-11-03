#!/usr/bin/env bash
set -euo pipefail

case_dir="$(cd "$(dirname "$0")" && pwd)"
. "$case_dir/../lib/scaffold.sh"

scaffold_native_toolchain_ask xcode
