# duo-de <sup><sup>[surface-duo desktop experience]</sup></sup>

This is a GSI variant rom build targetted for Microsoft Surface Duo with the intention of using the Surface Duo as a desktop environment using experimental floating window features. This build combines gapps/vanila variants of the GSI rom from [ponces](https://github.com/ponces/treble_aosp) with desktop mode enabled + various tweaks to make it nice and smooth with the help of [thain](https://github.com/thai-ng) tweaks. All credits go to respective developers. Desktop mode can be disabled from the ``home settings``.


<p align="center">
<img src="images/src-duo.png" alt="drawing" style="width:600px;"/> </p>

## Posture Engine

Thanks to [thain](https://github.com/thai-ng), duo react to various duo postures and the hinge gaps can be enabled/disabled through the treble app.
<p align="center">
<img src="images/duo-1.png" alt="drawing" style="height:300px;" /> 
<img src="images/duo-2.png" alt="drawing" style="height:300px;"/> </p>


## Flashing steps
**Try this at your own risk and proceed with caution!**

Following are the steps to flash this image to your surface duo.

1. Download the release 
```shell
wget https://github.com/Archfx/duo-de/releases/download/<<version>>/aosp-arm64-ab-gapps-14.0-<<version>>.img.xz
tar -xf aosp-arm64-ab-gapps-14.0-<<version>>.img.xz
# or
gunzip aosp-arm64-ab-gapps-14.0-<<version>>.img.xz
```
2. If you are migrating from Android 12L (stock) follow this step. You need to unlock the bootloader before proceeding. Please pay attention to commands, do not copy and execute the commands blindly.
```shell
adb reboot fastboot
fastboot delete-logical-partition system_ext
fastboot delete-logical-partition product

#get the current slot
fastboot getvar current-slot
# if current slot is a, delete the system_b
fastboot delete-logical-partition system_b
# if current slot is b, delete the system_a
fastboot delete-logical-partition system_a

fastboot flash system aosp-arm64-ab-gapps-14.0-<<version>>.img
fastboot reboot 
```
3. Migrating from 13/14 pixel experience, follow the below steps 
```shell
adb reboot fastboot
fastboot flash system aosp-arm64-ab-gapps-14.0-<<version>>.img
fastboot reboot 
```
4. Once you flash a **duo-de** version using the above steps, subsequent updates will be received using OTA. You can check updates using ``settings -> system -> system updates``.

## Issues

Any issues, please 
[open an issue](https://github.com/Archfx/duo-de/issues/new/choose) with a detailed description.

## Credits
These people have helped this project in some way or another, so they should be the ones who receive all the credit:

[phhusson](https://github.com/phhusson) [AndyYan](https://github.com/AndyCGYan) [eremitein](https://github.com/eremitein) [kdrag0n](https://github.com/kdrag0n) [Peter Cai](https://github.com/PeterCxy) [haridhayal11](https://github.com/haridhayal11) [sooti](https://github.com/sooti) [Iceows](https://github.com/Iceows) [ChonDoit](https://github.com/ChonDoit) [ponces](https://github.com/ponces) [thai-ng](https://github.com/thai-ng) [Axel](https://github.com/axel358)


## Disclaimer
THIS REPOSITORY CONTAINS A CUSTOM ANDROID GENERIC SYSTEM IMAGE (GSI) ROM PROVIDED "AS IS," WITHOUT WARRANTY OF ANY KIND. USE, DOWNLOAD, OR INSTALLATION OF THIS SOFTWARE IS AT YOUR OWN RISK. THE AUTHORS ARE NOT LIABLE FOR ANY DAMAGES, INCLUDING BUT NOT LIMITED TO DEVICE DAMAGE, DATA LOSS, OR OTHER ISSUES RESULTING FROM THE USE OR INSTALLATION OF THIS ROM. INSTALLING CUSTOM ROMS MAY VOID YOUR DEVICE'S WARRANTY AND COULD BRICK YOUR DEVICE, RENDERING IT UNUSABLE. VERIFY COMPATIBILITY WITH YOUR DEVICE BEFORE INSTALLATION. NO GUARANTEE OF UPDATES, FIXES, OR SUPPORT IS PROVIDED. THIRD-PARTY SOFTWARE INCLUDED IS SUBJECT TO ITS OWN TERMS. MODIFICATION AND REDISTRIBUTION ARE PERMITTED UNDER THE PROVIDED LICENSE, BUT AUTHORS DISCLAIM LIABILITY FOR ISSUES ARISING FROM SUCH ACTIONS. BY PROCEEDING, YOU ACCEPT THESE TERMS. IF YOU DO NOT AGREE, DO NOT USE THIS SOFTWARE. 






