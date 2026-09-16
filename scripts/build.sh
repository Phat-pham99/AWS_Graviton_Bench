#!/usr/bin/env bash
# Builds and pushes the workload microservice as a multi-arch manifest list so the
# SUTs pull the correct architecture image automatically (amd64 for control,
# arm64 for test). Requires Docker Buildx.
#
# Usage:
#   ./scripts/build.sh <registry>[:<repo>] [tag]
#   BUILDX_PLATFORMS=linux/amd64,linux/arm64 ./scripts/build.sh $ECR_URL
set -euo pipefail

REPO="${1:?usage: build.sh <registry-repo> [tag]}"
TAG="${2:-latest}"
PLATFORMS="${BUILDX_PLATFORMS:-linux/amd64,linux/arm64}"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

docker buildx use graviton-bench 2>/dev/null || \
  docker buildx create --name graviton-bench --use

docker buildx build \
  --platform "${PLATFORMS}" \
  --tag "${REPO}:${TAG}" \
  --push \
  "${ROOT}/workload"

echo "pushed ${REPO}:${TAG} for ${PLATFORMS}"
