#!/bin/bash

set -e

patches="$(readlink -f -- $1)"
tree="$2"

for project in $(cd $patches/patches/$tree; echo *); do
    p="$(tr _ / <<<$project |sed -e 's;platform/;;g')"
    [ "$p" == build ] && p=build/make
    [ "$p" == treble/app ] && p=treble_app
    [ "$p" == vendor/hardware/overlay ] && p=vendor/hardware_overlay
    pushd $p &>/dev/null
    for patch in $patches/patches/$tree/$project/*.patch; do
        git am $patch || exit
    done
    popd &>/dev/null
done
