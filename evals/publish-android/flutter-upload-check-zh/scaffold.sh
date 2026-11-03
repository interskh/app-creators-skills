#!/usr/bin/env bash
set -euo pipefail

case_dir="$(cd "$(dirname "$0")" && pwd)"
. "$case_dir/../lib/scaffold.sh"

seed_native_past_build flutter 36 readings
