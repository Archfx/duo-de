#!/bin/bash

echo
echo "--------------------------------------"
echo "          AOSP 16.0 Buildbot          "
echo "                  by                  "
echo "                ponces                "
echo "--------------------------------------"
echo

set -e


export BUILD_NUMBER="$(date +%y%m%d)"

BUILD_ROOT="$PWD"
BUILD_DIR=$PWD/duo-de/builds


initRepos() {
    echo "--> Initializing workspace"
    
    repo init -u https://android.googlesource.com/platform/manifest -b android-16.0.0_r2 --git-lfs
    echo

    echo "--> Preparing local manifest"
    mkdir -p .repo/local_manifests
    cp $BUILD_ROOT/build/default.xml .repo/local_manifests/default.xml
    cp $BUILD_ROOT/build/remove.xml .repo/local_manifests/remove.xml
    echo
}

syncRepos() {
    echo "--> Syncing repos"
    repo forall -c 'git clean -fdx'
    repo forall -c "git reset --hard HEAD"
    # repo forall -c 'git rebase --abort 2>/dev/null; git am --abort 2>/dev/null'
    repo sync -c --force-sync --no-clone-bundle --no-tags -j$(nproc --all)
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

START=$(date +%s)

initRepos
syncRepos
applyPatches

END=$(date +%s)
ELAPSEDM=$(($(($END-$START))/60))
ELAPSEDS=$(($(($END-$START))-$ELAPSEDM*60))

echo "--> Clean completed in $ELAPSEDM minutes and $ELAPSEDS seconds"
echo
