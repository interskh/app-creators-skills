#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"

if [ "$#" -ne 1 ]; then
  echo "usage: scripts/new-skill.sh <name>" >&2
  exit 1
fi

name="$1"

if [ "${#name}" -lt 1 ] || [ "${#name}" -gt 64 ] \
  || ! [[ "$name" =~ ^[a-z0-9]([a-z0-9-]*[a-z0-9])?$ ]] \
  || [[ "$name" == *--* ]]; then
  echo "error: invalid name '$name': use 1-64 chars of [a-z0-9-], no leading/trailing hyphen, no '--'" >&2
  exit 1
fi

dest="$root/skills/$name"

if [ -e "$dest" ]; then
  echo "error: skills/$name already exists" >&2
  exit 1
fi

cp -R "$root/templates/skill" "$dest"
sed -i.bak "s/__NAME__/$name/g" "$dest/SKILL.md"
rm "$dest/SKILL.md.bak"

echo "created:"
(cd "$root" && find "skills/$name" -type f | sort | sed 's/^/  /')
echo "fill in by hand in skills/$name/SKILL.md: __STAGE__ (publish | acquire | monetize | core), __PLATFORM__ (web | ios | android | all)"
