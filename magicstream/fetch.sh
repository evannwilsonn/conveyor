#!/usr/bin/env sh
# Fetches MagicStream (Gavin Lon's React + Go + MongoDB course app) at the commit this pipeline
# was built against, into ./src. The app's code isn't copied into this repo: it has no license,
# so the pipeline builds it from the author's own repository instead of redistributing it.
set -eu
cd "$(dirname "$0")"
REPO=https://github.com/GavinLonDigital/MagicStream.git
COMMIT=350326593117d59f4a0fa5fc5d694b8455fd872a   # "Update README.md", 1 Oct 2025

if [ -d src/.git ] && [ "$(git -C src rev-parse HEAD)" = "$COMMIT" ]; then
  echo "src/ already at $COMMIT"
  exit 0
fi
rm -rf src
git init -q src
git -C src remote add origin "$REPO"
git -C src fetch -q --depth 1 origin "$COMMIT"
git -C src checkout -q FETCH_HEAD
echo "fetched MagicStream at $COMMIT into src/"
