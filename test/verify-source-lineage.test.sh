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
touch package/static/app.js package/static/output.css package/views/index.hbs
git add .
git commit -qm base
git branch -M dev
git push -q origin dev
reviewed=$(git rev-parse HEAD)
"$script" "$reviewed" dev false

printf generated > package/static/app.js
git add package/static/app.js
git commit -qm generated-asset
if "$script" "$reviewed" dev false; then
  echo 'expected generated commit to require explicit opt-in' >&2
  exit 1
fi
"$script" "$reviewed" dev true

printf staged > package/static/output.css
git add package/static/output.css
if "$script" "$reviewed" dev true; then
  echo 'expected staged change to fail' >&2
  exit 1
fi
git reset -q package/static/output.css
git checkout -q -- package/static/output.css
printf unstaged > package/views/index.hbs
if "$script" "$reviewed" dev true; then
  echo 'expected unstaged change to fail' >&2
  exit 1
fi
git checkout -q -- package/views/index.hbs
printf untracked > package/untracked.txt
if "$script" "$reviewed" dev true; then
  echo 'expected untracked change to fail' >&2
  exit 1
fi
rm -f package/untracked.txt
printf ignored > package/ignored.txt
printf 'package/ignored.txt\n' > .gitignore
if "$script" "$reviewed" dev true; then
  echo 'expected ignored change to fail' >&2
  exit 1
fi
rm -f package/ignored.txt .gitignore

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
