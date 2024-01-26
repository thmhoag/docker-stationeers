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

MAX_RETRIES=10
retry_count=0

set +eo pipefail # let the following sub command fail and we'll handle it
while [ $retry_count -lt $MAX_RETRIES ]; do
    APP_INFO=$(docker run --rm steamcmd/steamcmd:latest +login anonymous +app_info_print $APP_ID +quit)
    if [ -n "$APP_INFO" ]; then
        echo "Steam app info retrieved successfully"
        break
    else
        echo "Unable to get app info from Steam. Retrying..."
        ((retry_count++))
        sleep 1
    fi
done

# make sure failures after this fail the script
set -eo pipefail

MANIFEST_REGEX="\d{16,19}"
NEW_VERSION=$(echo $APP_INFO | grep -oP '600762" \{\s*"config" \{\s*"oslist" "linux" "osarch" "64" \}\s*"manifests" \{\s*"public" \{\s*"gid" "\K\d+')
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