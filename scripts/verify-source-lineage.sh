#!/usr/bin/env bash
set -euo pipefail

expected="${1:-}"
ref="${2:-}"
allow_generated="${3:-false}"
if [[ ! "$expected" =~ ^[0-9a-f]{40}$ ]]; then
  echo "::error::expected_source_sha must be a 40-character commit SHA" >&2
  exit 1
fi
if [ -z "$ref" ]; then
  echo "::error::publish branch is required" >&2
  exit 1
fi

dirty=$(git status --porcelain=v1 --untracked-files=all --ignored)
if [ -n "$dirty" ]; then
  echo "::error::Strict publish refuses staged, unstaged, untracked, or ignored files before packaging:" >&2
  printf '%s\n' "$dirty" >&2
  exit 1
fi

local_sha=$(git rev-parse HEAD)
remote_sha=$(git ls-remote origin "refs/heads/${ref}" | awk 'NR == 1 { print $1 }')
if [ "$remote_sha" != "$expected" ]; then
  echo "::error::Remote ${ref} tip ${remote_sha:-<missing>} does not match reviewed source ${expected}" >&2
  exit 1
fi
if [ "$allow_generated" != "true" ]; then
  if [ "$local_sha" != "$expected" ]; then
    echo "::error::Local HEAD ${local_sha} differs from reviewed source ${expected}; generated-commit exception was not enabled" >&2
    exit 1
  fi
elif ! git merge-base --is-ancestor "$expected" "$local_sha"; then
  echo "::error::Local HEAD ${local_sha} is not descended from reviewed source ${expected}" >&2
  exit 1
fi

while IFS= read -r path; do
  case "$path" in
    package/static/app.js|package/static/output.css|package/views/index.hbs) ;;
    *)
      echo "::error::Strict publish lineage contains an unreviewed local change: ${path}" >&2
      exit 1
      ;;
  esac
done < <(git diff --name-only "${expected}..${local_sha}")

echo "Strict publish lineage verified: remote=${expected}, local=${local_sha}"
