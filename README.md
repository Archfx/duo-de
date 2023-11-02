# Surface Duo: TrebleDroid AOSP GSI

credits to [Thai-ng](https://github.com/thai-ng/treble_build_aosp)

## Build
To get started with building AOSP GSI, you'll need to get familiar with [Git and Repo](https://source.android.com/source/using-repo.html) as well as [How to build a GSI](https://github.com/phhusson/treble_experimentations/wiki/How-to-build-a-GSI%3F).

- Pull the docker image
    ```
    docker pull archfx/android
    ```
- Create a new working directory for your AOSP build and navigate to it:
    ```
    mkdir aosp; cd aosp
    ```
- Clone this repo:
    ```
    git clone https://github.com/archfx/epsilon -b android-14.0 treble_build_aosp
    ```
- Mount the directory to the docker container
    ```
    docker run -t -p 6080:6080 -v "${PWD}/:/treble_build_aosp" -w /treble_build_aosp --name epsilon archfx/android
    ```
- Connect to the container
    ```
    docker exec -it epsilon /bin/bash
    ```
- Configure git username for repo:
    ```
    git config --global user.name "your username"
    git config --global user.email yourmail@example.com
    ulimit -n 2048
    git config --global gc.auto 1024
    ```
- Finally, start the build script:
    ```
    bash treble_build_aosp/build.sh
    ```

## Issues
[Open issue](https://github.com/ponces/treble_build_aosp/issues/new/choose)

## Credits
These people have helped this project in some way or another, so they should be the ones who receive all the credit:
- [phhusson](https://github.com/phhusson)
- [AndyYan](https://github.com/AndyCGYan)
- [eremitein](https://github.com/eremitein)
- [kdrag0n](https://github.com/kdrag0n)
- [Peter Cai](https://github.com/PeterCxy)
- [haridhayal11](https://github.com/haridhayal11)
- [sooti](https://github.com/sooti)
- [Iceows](https://github.com/Iceows)
- [ChonDoit](https://github.com/ChonDoit)
