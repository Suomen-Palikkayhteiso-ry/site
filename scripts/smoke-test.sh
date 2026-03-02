#!/usr/bin/env bash
# Smoke test: verify the live site is accessible and has a build-sha meta tag.
# Usage: SITE_URL=https://org.github.io/repo bash scripts/smoke-test.sh

set -euo pipefail

SITE_URL="${SITE_URL:?SITE_URL env var required}"

echo "Fetching $SITE_URL ..."
BODY=$(curl -fsSL "$SITE_URL")

SHA=$(echo "$BODY" | grep -oP '(?<=<meta name="build-sha" content=")[^"]+')
if [ -z "$SHA" ]; then
  echo "FAIL: build-sha meta tag not found in $SITE_URL"
  exit 1
fi
echo "OK: build-sha = $SHA"

echo "Fetching $SITE_URL/site-config.json ..."
CONFIG=$(curl -fsSL "$SITE_URL/site-config.json")
CONFIG_SHA=$(echo "$CONFIG" | python3 -c "import sys,json; print(json.load(sys.stdin)['buildSha'])")
if [ "$SHA" != "$CONFIG_SHA" ]; then
  echo "FAIL: build-sha in HTML ($SHA) != buildSha in site-config.json ($CONFIG_SHA)"
  exit 1
fi
echo "OK: SHAs match"

echo "Smoke test passed."
