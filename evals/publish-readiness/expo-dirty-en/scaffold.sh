#!/usr/bin/env bash
set -euo pipefail

case_dir="$(cd "$(dirname "$0")" && pwd)"
. "$case_dir/../lib/scaffold.sh"

scaffold_expo_assessed
printf '\nexport const dirty = true;\n' >> App.tsx
