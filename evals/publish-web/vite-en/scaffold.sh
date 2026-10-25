#!/usr/bin/env bash
set -euo pipefail

pin=95c2f95
case_dir="$(cd "$(dirname "$0")" && pwd)"
fixture="$case_dir/../../../../app-creators-fixtures/todo-vite"

if [ ! -d "$fixture" ]; then
  common="$(cd "$case_dir" && git rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)"
  if [ -n "$common" ]; then
    fixture="$(dirname "$common")/../app-creators-fixtures/todo-vite"
  fi
fi

if [ ! -d "$fixture" ]; then
  echo "scaffold: fixture not found; clone app-creators-fixtures next to the plugin repo (expected ../app-creators-fixtures/todo-vite)" >&2
  exit 1
fi

if ! (cd "$fixture" && git cat-file -e "$pin^{commit}" 2>/dev/null); then
  echo "scaffold: commit $pin is not in app-creators-fixtures; run git fetch there" >&2
  exit 1
fi

(cd "$fixture" && git archive --format=tar "$pin" .) | tar -xf -
mkdir -p .app-creators
cp "$case_dir/state.md" .app-creators/state.md
