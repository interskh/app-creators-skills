#!/usr/bin/env bash
# Stand-in for gh in tests/metrics.test.sh. Accepts only the exact calls the script is
# contracted to make, then prints what `gh api ... --jq` would print.
set -u

echo "$*" >> "${FAKE_GH_LOG:-/dev/null}"

tab=$'\t'
repo="interskh/app-creators-skills"

if [ "${1:-}" = api ] && [ "${2:-}" = --hostname ] && [ "${3:-}" = github.com ] && [ "${5:-}" = --jq ] && [ "$#" -eq 6 ]; then
  case "${4:-}" in
    "repos/$repo/traffic/clones") key=CLONES; want='[.count,.uniques]|@tsv'; default="55${tab}37" ;;
    "repos/$repo/traffic/views") key=VIEWS; want='[.count,.uniques]|@tsv'; default="10${tab}4" ;;
    "repos/$repo") key=REPO; want='[.stargazers_count,.forks_count]|@tsv'; default="5${tab}2" ;;
    *) key="" ;;
  esac
  if [ -n "$key" ] && [ "${6:-}" = "$want" ]; then
    failvar="FAKE_FAIL_$key"
    valvar="FAKE_VAL_$key"
    case "${!failvar:-}" in
      auth)
        echo "To get started with GitHub CLI, please run:  gh auth login" >&2
        echo "Alternatively, populate the GH_TOKEN environment variable with a GitHub API authentication token." >&2
        exit 4
        ;;
      403)
        echo "gh: Resource not accessible by personal access token (HTTP 403)" >&2
        exit 1
        ;;
      net)
        echo 'error connecting to api.github.com' >&2
        exit 1
        ;;
    esac
    if [ "${!valvar+set}" = set ]; then
      printf '%s\n' "${!valvar}"
    else
      printf '%s\n' "$default"
    fi
    exit 0
  fi
fi

echo "fake gh: unexpected call: $*" >&2
exit 97
