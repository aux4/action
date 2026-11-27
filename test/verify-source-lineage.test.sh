#!/usr/bin/env bash
set -euo pipefail

root=$(mktemp -d)
trap 'rm -rf "$root"' EXIT
script="$(cd "$(dirname "$0")/.." && pwd)/scripts/verify-source-lineage.sh"
bare="$root/bare.git"
git init --bare -q "$bare"
git clone -q "$bare" "$root/work"
cd "$root/work"
git config user.email test@example.test
git config user.name test
mkdir -p package/static package/views
printf base > package/.aux4
git add .
git commit -qm base
git branch -M dev
git push -q origin dev
reviewed=$(git rev-parse HEAD)

printf generated > package/static/app.js
git add package/static/app.js
git commit -qm generated
"$script" "$reviewed" dev

git clone -q --branch dev "$bare" "$root/other"
cd "$root/other"
git config user.email test@example.test
git config user.name test
printf drift >> package/.aux4
git add package/.aux4
git commit -qm drift
git push -q origin dev
cd "$root/work"
if "$script" "$reviewed" dev; then
  echo 'expected remote drift to fail' >&2
  exit 1
fi

git fetch -q origin dev
git reset -q --hard "$reviewed"
printf unreviewed > package/README.md
git add package/README.md
git commit -qm unreviewed
git push -q --force origin dev
if "$script" "$reviewed" dev; then
  echo 'expected unreviewed local change to fail' >&2
  exit 1
fi
echo 'verify-source-lineage tests passed'
