#!/usr/bin/env bash
set -euo pipefail

environment="$1"
image="$2"

case "$environment" in
  prod) port=8080 ;;
  qa) port=8081 ;;
  *) echo "Invalid environment"; exit 1 ;;
esac

cd "$(dirname "$0")"

# Use the workflow's temporary registry token, then remove credentials.
read -r registry_token
export DOCKER_CONFIG
DOCKER_CONFIG="$(mktemp -d)"
trap 'rm -rf "$DOCKER_CONFIG"' EXIT

printf '%s' "$registry_token" |
  docker login ghcr.io -u dan38-cmyk --password-stdin
unset registry_token

export IMAGE_REF="$image"
export WEB_PORT="$port"

docker compose -p "exam1-$environment" -f compose.yml pull

printf 'IMAGE_REF=%s\nWEB_PORT=%s\n' "$image" "$port" > release.env

docker compose --env-file release.env \
  -p "exam1-$environment" -f compose.yml up -d

curl --retry 12 --retry-connrefused --retry-delay 2 \
  --max-time 10 -fsS "http://127.0.0.1:$port/" > /dev/null

echo "Deployed $image to $environment"
