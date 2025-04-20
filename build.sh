#!/bin/bash

echo
echo "--------------------------------------"
echo "          AOSP 15.0 Buildbot          "
echo "                  by                  "
echo "                ponces                "
echo "--------------------------------------"
echo

set -e


export BUILD_NUMBER="$(date +%y%m%d)"

BUILD_ROOT="$PWD/treble_aosp"
BUILD_DIR=$PWD/duo-de/builds


initRepos() {
    echo "--> Initializing workspace"
    repo init -u https://android.googlesource.com/platform/manifest -b android-15.0.0_r26 --git-lfs
    echo

    echo "--> Preparing local manifest"
    mkdir -p .repo/local_manifests
    cp $BUILD_ROOT/build/default.xml .repo/local_manifests/default.xml
    cp $BUILD_ROOT/build/remove.xml .repo/local_manifests/remove.xml
    echo
}

syncRepos() {
    echo "--> Syncing repos"
    repo forall -c 'git checkout -f' 
    repo forall -c 'git clean -fd'
    repo sync -c --force-sync --no-clone-bundle --no-tags -j$(nproc --all) || repo sync -c --force-sync --no-clone-bundle --no-tags -j$(nproc --all)
    echo
}

applyPatches() {
    echo "--> Applying TrebleDroid patches"
    bash $BUILD_ROOT/patch.sh $BUILD_ROOT trebledroid
    echo

    echo "--> Applying personal patches"
    bash $BUILD_ROOT/patch.sh $BUILD_ROOT personal
    echo

    echo "--> Applying DUO-DE patches"
    bash $BUILD_ROOT/patch.sh $BUILD_ROOT duo
    echo

    echo "--> Generating makefiles"
    cd device/phh/treble
    cp $BUILD_ROOT/build/aosp.mk .
    bash generate.sh aosp
    cd ../../..
    echo
}

setupEnv() {
    echo "--> Setting up build environment"
    mkdir -p $BUILD_DIR
    source build/envsetup.sh
    source build/core/build_id.mk
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
    lunch "$1"-bp1a-userdebug
    make -j$(nproc --all) installclean
    make -j$(nproc --all) systemimage
    make -j$(nproc --all) target-files-package otatools
    bash $BUILD_ROOT/sign.sh "../archfx-priv/keys" $OUT/signed-target_files.zip
    unzip -jqo $OUT/signed-target_files.zip IMAGES/system.img -d $OUT
    mv $OUT/system.img $BUILD_DIR/system-"$1".img

    echo "image copied to $BUILD_DIR/system-"$1".img"
    echo
}

buildVndkliteVariant() {
    echo "--> Building $1-vndklite"
    cd treble_adapter
    sudo bash lite-adapter.sh "64" $BUILD_DIR/system-"$1".img
    mv s.img $BUILD_DIR/system-"$1"-vndklite.img
    sudo rm -rf d tmp
    cd ..
    echo
}

buildVariants() {
    # buildVariant treble_a64_bvN
    # buildVariant treble_a64_bgN

    buildVariant treble_arm64_bvN
    buildVariant treble_arm64_bgN
    
 
    # buildVndkliteVariant treble_a64_bvN
    # buildVndkliteVariant treble_a64_bgN
    # buildVndkliteVariant treble_arm64_bvN
    # buildVndkliteVariant treble_arm64_bgN
}

generatePackages() {
    echo "--> Generating packages"
    buildDate="$(date +%Y%m%d)"
    find $BUILD_DIR/ -name "system-treble_*.img" | while read file; do
        filename="$(basename $file)"
        [[ "$filename" == *"_a64"* ]] && arch="arm32_binder64" || arch="arm64"
        [[ "$filename" == *"_bvN"* ]] && variant="vanilla" || variant="gapps"
        [[ "$filename" == *"-vndklite"* ]] && vndk="-vndklite" || vndk=""
        name="aosp-${arch}-ab-${variant}${vndk}-15.0-$buildDate"
        xz -cv "$file" -T0 > $BUILD_DIR/"$name".img.xz
    done
    rm -rf $BUILD_DIR/system-*.img
    echo
}

generateOta() {
    echo "--> Generating OTA file"
    version="$(date +v%Y.%m.%d)"
    buildDate="$(date +%Y%m%d)"
    timestamp="$START"
    json="{\"version\": \"$version\",\"date\": \"$timestamp\",\"variants\": ["
    find $BUILD_DIR/ -name "aosp-*-15.0-$buildDate.img.xz" | sort | {
        while read file; do
            filename="$(basename $file)"
            [[ "$filename" == *"-arm32"* ]] && arch="a64" || arch="arm64"
            [[ "$filename" == *"-vanilla"* ]] && variant="v" || variant="g"
            [[ "$filename" == *"-vndklite"* ]] && vndk="-vndklite" || vndk=""
            name="treble_${arch}_b${variant}N${vndk}"
            size=$(wc -c $file | awk '{print $1}')
            url="https://github.com/archfx/duo-de/releases/download/$version/$filename"
            json="${json} {\"name\": \"$name\",\"size\": \"$size\",\"url\": \"$url\"},"
        done
        json="${json%?}]}"
        echo "$json" | jq . > $BUILD_ROOT/config/ota.json
    }
    echo
}

uploadOTA() {
    bash $BUILD_ROOT/upload.sh
}



START=$(date +%s)

# initRepos
# syncRepos
# applyPatches
setupEnv
buildTrebleApp
buildVariants
generatePackages
generateOta
uploadOTA

END=$(date +%s)
ELAPSEDM=$(($(($END-$START))/60))
ELAPSEDS=$(($(($END-$START))-$ELAPSEDM*60))

echo "--> Buildbot completed in $ELAPSEDM minutes and $ELAPSEDS seconds"
echo
