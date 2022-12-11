#!/bin/bash

# fail entire script if one command fails
set -eo pipefail

APP_ID=600760
DEPOT_ID=600762
REPO=thmhoag/stationeers

echo "Getting current $REPO manifest version..."

TOKEN=$(curl -s "https://auth.docker.io/token?service=registry.docker.io&scope=repository:${REPO}:pull" | jq -r '.token')
CURRENT_VERSION=$(curl -s -H "Authorization: Bearer $TOKEN" "https://registry-1.docker.io/v2/${REPO}/manifests/latest" | jq ".history[0].v1Compatibility" -r | jq -r .config.Labels.MANIFEST_ID)
echo "Current version: $CURRENT_VERSION"

APP_INFO=$(docker run --rm steamcmd/steamcmd:latest +login anonymous +app_info_print $APP_ID +quit)
MANIFEST_REGEX="\d{16,19}"
NEW_VERSION=$(echo "$APP_INFO" | sed -e "1,/$DEPOT_ID/d" -e '1,/manifests/d' -e '/maxsize/,$d' | grep --perl-regexp --only "public\"\h+\"\K$MANIFEST_REGEX")
echo "New version: $NEW_VERSION"

if [ -z "$CURRENT_VERSION" ] || [ -z "$NEW_VERSION" ]; then
    echo "Failed to get version info!"
    exit 1
fi

if [ "$CURRENT_VERSION" = "$NEW_VERSION" ]; then
    echo "Current version is latest. No update needed."
    exit 0
fi

echo "Building new version: $NEW_VERSION"
docker build . -t $REPO:$NEW_VERSION --build-arg MANIFEST_ID=$NEW_VERSION
docker tag $REPO:$NEW_VERSION $REPO:latest

echo "Pushing new version: $NEW_VERSION"
docker push $REPO:$NEW_VERSION
docker push $REPO:latest

echo "Complete."