#!/bin/bash

echo
echo "--------------------------------------"
echo "         AOSP 14.0 Uploadbot          "
echo "                  by                  "
echo "                ponces                "
echo "--------------------------------------"
echo

set -e

BL=$PWD/treble_aosp
BD=$HOME/builds
TAG="$(date +v%Y.%m.%d)"
GUSER="archfx"
GREPO="epsilon"

SKIPOTA=false
if [ "$1" == "--skip-ota" ]; then
    SKIPOTA=true
fi

createRelease() {
    echo "--> Creating release $TAG"
    res=$(curl -s -L -X POST \
        "https://api.github.com/repos/$GUSER/$GREPO/releases" \
        -H "Accept: application/vnd.github+json" \
        -H "Authorization: Bearer $GITHUB_API_TOKEN" \
        -d "{\"tag_name\":\"$TAG\",\"name\":\"AOSP 14.0 $TAG\",\"body\":\"## Changelog\n- ...\n\n## Notes\n- ...\",\"draft\":true}")
    id=$(echo "$res" | jq -rc ".id")
    echo
}

uploadAssets() {
    buildDate="$(date +%Y%m%d)"
    find $BD/ -name "aosp-*-14.0-$buildDate.img.xz" | while read file; do
        echo "--> Uploading $(basename $file)"
        curl -o /dev/null -s -L -X POST \
            "https://uploads.github.com/repos/$GUSER/$GREPO/releases/$id/assets?name=$(basename $file)" \
            -H "Accept: application/vnd.github+json" \
            -H "Authorization: Bearer $GITHUB_API_TOKEN" \
            -H "Content-Type: application/octet-stream" \
            -T "$file"
        echo
    done
}

updateOta() {
    echo "--> Updating OTA file"
    pushd "$BL"
    git add config/ota.json
    git commit -m "build: Bump OTA to $TAG"
    git push
    popd
    echo
}

START=$(date +%s)

createRelease
uploadAssets
[ "$SKIPOTA" = false ] && updateOta

END=$(date +%s)
ELAPSEDM=$(($(($END-$START))/60))
ELAPSEDS=$(($(($END-$START))-$ELAPSEDM*60))

echo "--> Uploadbot completed in $ELAPSEDM minutes and $ELAPSEDS seconds"
echo
