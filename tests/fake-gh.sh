#!/usr/bin/env bash
# Stand-in for gh in tests/metrics.test.sh. Prints what `gh api ... --jq` would print.
set -u

echo "$*" >> "${FAKE_GH_LOG:-/dev/null}"

tab=$'\t'

case "${1:-}" in
  auth)
    if [ "${FAKE_AUTH:-ok}" = ok ]; then
      exit 0
    fi
    echo "You are not logged into any GitHub hosts. To log in, run: gh auth login" >&2
    exit 1
    ;;
  api)
    case "${2:-}" in
      */traffic/clones) key=CLONES; default="55${tab}37" ;;
      */traffic/views) key=VIEWS; default="10${tab}4" ;;
      *) key=REPO; default="5${tab}2" ;;
    esac
    failvar="FAKE_FAIL_$key"
    valvar="FAKE_VAL_$key"
    case "${!failvar:-}" in
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
    ;;
esac

echo "fake gh: unexpected call: $*" >&2
exit 99
