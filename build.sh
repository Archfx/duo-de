#!/bin/bash

echo
echo "--------------------------------------"
echo "          AOSP 14.0 Buildbot          "
echo "                  by                  "
echo "                ponces                "
echo "--------------------------------------"
echo

set -e

BL=$PWD/treble_build_aosp
BD=$BL/out/builds

initRepos() {
    if [ ! -d .repo ]; then
        echo "--> Initializing workspace"
        repo init -u https://android.googlesource.com/platform/manifest -b android-14.0.0_r11
        echo

        echo "--> Preparing local manifest"
        mkdir -p .repo/local_manifests
        cp $BL/manifest.xml .repo/local_manifests/aosp.xml
        echo
    fi
}

syncRepos() {
    echo "--> Syncing repos"
    repo sync -c --force-sync --no-clone-bundle --no-tags -j$(nproc --all)
    echo
}

applyPatches() {
    echo "--> Applying TrebleDroid patches"
    bash $BL/apply-patches.sh $BL trebledroid
    echo

    echo "--> Applying personal patches"
    bash $BL/apply-patches.sh $BL personal
    echo

    echo "--> Generating makefiles"
    cd device/phh/treble
    cp $BL/aosp.mk .
    bash generate.sh aosp
    cd ../../..
    echo
}

setupEnv() {
    echo "--> Setting up build environment"
    echo $PWD
    source build/envsetup.sh #&>/dev/null
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

buildVanillaVariant() {
    echo "--> Building treble_arm64_bvN"
    lunch treble_arm64_bvN-userdebug
    make -j$(nproc --all) installclean
    make -j$(nproc --all) systemimage
    mv $OUT/system.img $BD/system-treble_arm64_bvN.img
    echo
}

buildGappsVariant() {
    echo "--> Building treble_arm64_bgN"
    lunch treble_arm64_bgN-userdebug
   # make -j$(nproc --all) installclean
    make -j$(nproc --all) systemimage
   

    mv $OUT/system.img $BD/system-duo-aosp.img
    echo
}


buildVndkliteVariants() {
    echo "--> Building treble_arm64_bvN-vndklite"
    cd treble_adapter
    sudo bash lite-adapter.sh 64 $BD/system-treble_arm64_bvN.img
    mv s.img $BD/system-treble_arm64_bvN-vndklite.img
    rm -rf d tmp
    echo "--> Building treble_arm64_bgN-vndklite"
    bash lite-adapter.sh 64 $BD/system-treble_arm64_bgN.img
    mv s.img $BD/system-treble_arm64_bgN-vndklite.img
    rm -rf d tmp
    cd ..
    echo
}

generatePackages() {
    echo "--> Generating packages"
    buildDate="$(date +%Y%m%d)"
    #xz -cv $BD/system-treble_arm64_bvN.img -T0 > $BD/aosp-arm64-ab-vanilla-14.0-$buildDate.img.xz
    #xz -cv $BD/system-treble_arm64_bvN-vndklite.img -T0 > $BD/aosp-arm64-ab-vanilla-vndklite-14.0-$buildDate.img.xz
    xz -cv $BD/system-duo-aosp.img -T0 > $BD/duo-aosp.img-14.0-$buildDate.img.xz
    #xz -cv $BD/system-treble_arm64_bgN-vndklite.img -T0 > $BD/aosp-arm64-ab-gapps-vndklite-14.0-$buildDate.img.xz
    rm -rf $BD/system-*.img
    echo
}

generateOta() {
    echo "--> Generating OTA file"
    version="$(date +v%Y.%m.%d)"
    buildDate="$(date +%Y%m%d)"
    timestamp="$START"
    json="{\"version\": \"$version\",\"date\": \"$timestamp\",\"variants\": ["
    find $BD/ -name "system-*-14.0-$buildDate.img.xz" | sort | {
        while read file; do
            filename="$(basename $file)"
            if [[ $filename == *"vanilla-vndklite"* ]]; then
                name="treble_arm64_bvN-vndklite"
            elif [[ $filename == *"gapps-vndklite"* ]]; then
                name="treble_arm64_bgN-vndklite"
            elif [[ $filename == *"vanilla"* ]]; then
                name="treble_arm64_bvN"
            else
                name="system-duo-aosp"
            fi
            size=$(wc -c $file | awk '{print $1}')
            url="https://github.com/archfx/epsilon/releases/download/$version/$filename"
            json="${json} {\"name\": \"$name\",\"size\": \"$size\",\"url\": \"$url\"},"
        done
        json="${json%?}]}"
        echo "$json" | jq . > $BL/ota.json
    }
    echo
}

START=$(date +%s)

#initRepos
syncRepos
#applyPatches
#setupEnv
#buildTrebleApp
#buildVanillaVariant
#buildGappsVariant
#buildVndkliteVariants
#generatePackages
#generateOta

END=$(date +%s)
ELAPSEDM=$(($(($END-$START))/60))
ELAPSEDS=$(($(($END-$START))-$ELAPSEDM*60))

echo "--> Buildbot completed in $ELAPSEDM minutes and $ELAPSEDS seconds"
echo
