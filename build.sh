#!/bin/bash

echo
echo "--------------------------------------"
echo "          AOSP 14.0 Buildbot          "
echo "                  by                  "
echo "                ponces                "
echo "--------------------------------------"
echo

set -e

BL=$PWD/treble_aosp
BD=$HOME/builds

initRepos() {
    echo "--> Initializing workspace"
    repo init -u https://android.googlesource.com/platform/manifest -b android-14.0.0_r37 --git-lfs
    echo

    echo "--> Preparing local manifest"
    mkdir -p .repo/local_manifests
    cp $BL/build/default.xml .repo/local_manifests/default.xml
    cp $BL/build/remove.xml .repo/local_manifests/remove.xml
    echo
}

syncRepos() {
    echo "--> Syncing repos"
    repo sync -c --force-sync --no-clone-bundle --no-tags -j$(nproc --all) || repo sync -c --force-sync --no-clone-bundle --no-tags -j$(nproc --all)
    echo
}

applyPatches() {
    echo "--> Applying TrebleDroid patches"
    bash $BL/patch.sh $BL trebledroid
    echo

    echo "--> Applying personal patches"
    bash $BL/patch.sh $BL personal
    echo

    echo "--> Generating makefiles"
    cd device/phh/treble
    cp $BL/build/aosp.mk .
    bash generate.sh aosp
    cd ../../..
    echo
}

setupEnv() {
    echo "--> Setting up build environment"
    source build/envsetup.sh &>/dev/null
    mkdir -p $BD
    echo
}

buildTrebleApp() {
    echo "--> Building treble_app"
    cd treble_app
    bash build.sh release
    cp TrebleApp.apk ../vendor/hardware_overlay/TrebleApp/app.apk
    cd ..
    echo
}

buildVariant() {
    echo "--> Building $1"
    lunch "$1"-ap1a-userdebug
    make -j$(nproc --all) installclean
    make -j$(nproc --all) systemimage
    mv $OUT/system.img $BD/system-"$1".img
    echo
}

buildVndkliteVariant() {
    echo "--> Building $1-vndklite"
    [[ "$1" == *"a64"* ]] && arch="32" || arch="64"
    cd treble_adapter
    sudo bash lite-adapter.sh "$arch" $BD/system-"$1".img
    mv s.img $BD/system-"$1"-vndklite.img
    sudo rm -rf d tmp
    cd ..
    echo
}

buildVariants() {
    buildVariant treble_a64_bvN
    buildVariant treble_a64_bgN
    buildVariant treble_arm64_bvN
    buildVariant treble_arm64_bgN
    buildVndkliteVariant treble_a64_bvN
    buildVndkliteVariant treble_a64_bgN
    buildVndkliteVariant treble_arm64_bvN
    buildVndkliteVariant treble_arm64_bgN
}

generatePackages() {
    echo "--> Generating packages"
    buildDate="$(date +%Y%m%d)"
    find $BD/ -name "system-treble_*.img" | while read file; do
        filename="$(basename $file)"
        [[ "$filename" == *"_a64"* ]] && arch="arm32_binder64" || arch="arm64"
        [[ "$filename" == *"_bvN"* ]] && variant="vanilla" || variant="gapps"
        [[ "$filename" == *"-vndklite"* ]] && vndk="-vndklite" || vndk=""
        name="aosp-${arch}-ab-${variant}${vndk}-14.0-$buildDate"
        xz -cv "$file" -T0 > $BD/"$name".img.xz
    done
    rm -rf $BD/system-*.img
    echo
}

generateOta() {
    echo "--> Generating OTA file"
    version="$(date +v%Y.%m.%d)"
    buildDate="$(date +%Y%m%d)"
    timestamp="$START"
    json="{\"version\": \"$version\",\"date\": \"$timestamp\",\"variants\": ["
    find $BD/ -name "aosp-*-14.0-$buildDate.img.xz" | sort | {
        while read file; do
            filename="$(basename $file)"
            [[ "$filename" == *"-arm32"* ]] && arch="a64" || arch="arm64"
            [[ "$filename" == *"-vanilla"* ]] && variant="v" || variant="g"
            [[ "$filename" == *"-vndklite"* ]] && vndk="-vndklite" || vndk=""
            name="treble_${arch}_b${variant}N${vndk}"
            size=$(wc -c $file | awk '{print $1}')
            url="https://github.com/ponces/treble_aosp/releases/download/$version/$filename"
            json="${json} {\"name\": \"$name\",\"size\": \"$size\",\"url\": \"$url\"},"
        done
        json="${json%?}]}"
        echo "$json" | jq . > $BL/config/ota.json
    }
    echo
}

START=$(date +%s)

initRepos
syncRepos
applyPatches
setupEnv
buildTrebleApp
buildVariants
generatePackages
generateOta

END=$(date +%s)
ELAPSEDM=$(($(($END-$START))/60))
ELAPSEDS=$(($(($END-$START))-$ELAPSEDM*60))

echo "--> Buildbot completed in $ELAPSEDM minutes and $ELAPSEDS seconds"
echo
