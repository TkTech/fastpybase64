#!/bin/sh
# Release a new version: ./release.sh 0.2.0
#
# Sets the version in pyproject.toml and src/fastpybase64.cpp, runs the tests
# in a fresh virtual environment, commits, tags vX.Y.Z and pushes. The tag
# starts .github/workflows/buildwheels.yml, which builds the wheels and the
# source distribution and uploads them to PyPI (secret PYPI_API_TOKEN).
set -eu

if [ $# -ne 1 ]; then
  echo "usage: $0 X.Y.Z" >&2
  exit 1
fi
VERSION=$1
TAG="v$VERSION"
PYTHON=${PYTHON:-python3}

if ! echo "$VERSION" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$'; then
  echo "error: the version must look like 1.2.3, got '$VERSION'" >&2
  exit 1
fi
cd "$(dirname "$0")"
REPO=$(pwd)
if [ "$(git rev-parse --abbrev-ref HEAD)" != "main" ]; then
  echo "error: releases are made from the main branch" >&2
  exit 1
fi
if [ -n "$(git status --porcelain)" ]; then
  echo "error: the working tree has uncommitted changes" >&2
  exit 1
fi
git fetch --quiet --tags origin
if git rev-parse --quiet --verify "refs/tags/$TAG" >/dev/null; then
  echo "error: tag $TAG already exists" >&2
  exit 1
fi
if [ "$(git rev-parse HEAD)" != "$(git rev-parse origin/main)" ]; then
  echo "error: main differs from origin/main; pull or push first" >&2
  exit 1
fi

"$PYTHON" - "$VERSION" <<'EOF'
import re, sys
version = sys.argv[1]
for path, pattern, replacement in [
    ("pyproject.toml", r'(?m)^version = "[^"]*"', f'version = "{version}"'),
    ("src/fastpybase64.cpp", r'#define FASTPYBASE64_VERSION "[^"]*"',
     f'#define FASTPYBASE64_VERSION "{version}"'),
]:
    with open(path) as f:
        text = f.read()
    text, count = re.subn(pattern, replacement, text, count=1)
    if count != 1:
        sys.exit(f"error: no version found in {path}")
    with open(path, "w") as f:
        f.write(text)
EOF

VENV=$(mktemp -d)
trap 'rm -rf "$VENV"' EXIT
"$PYTHON" -m venv "$VENV"
"$VENV/bin/python" -m pip install --quiet --upgrade pip
"$VENV/bin/python" -m pip install --quiet ".[test]"
(cd "$VENV" && "$VENV/bin/python" -m pytest -q "$REPO/tests")

# Nothing to commit when the version is already set (e.g. the first release).
git diff --quiet || git commit --quiet -am "Release $VERSION."
git tag -a "$TAG" -m "Release $VERSION"
git push --quiet origin main "$TAG"
echo "Pushed $TAG. Follow the upload at https://github.com/simdutf/fastpybase64/actions"
