# Surface-duo Dual Experience [duo-de][A16]


<img align="left" width="120" height="auto" alt="" src="images/delogo.svg"/>
The Surface Duo, Microsoft's dual-screen Android device, aimed to redefine mobile productivity by offering a unique form factor that combined the versatility of two screens with the familiarity of the Android operating system. Although Microsoft officially ceased updates and support for the Surface Duo line in early 2023, with AOSP GSI and the help of the open-source community, it is time to give a second life to this awesome and unique hardware.

DUO-DE is a GSI variant Android ROM created for Microsoft Surface Duo devices, offering a clean AOSP experience. This build combines gapps/vanila variants of the GSI ROM from [ponces](https://github.com/ponces/treble_aosp) with desktop mode enabled + various tweaks to make it nice and smooth with the help of [thain](https://github.com/thai-ng) tweaks. All credits go to respective developers. 
Before you proceed, please take a moment to read [this announcement](https://github.com/Archfx/duo-de/discussions/52) regarding this project. By using this ROM, you are agreeing to the [`DISCLAIMER`](#disclaimer).


![GitHub Downloads (all assets, all releases)](https://img.shields.io/github/downloads/archfx/duo-de/total?style=for-the-badge&label=duo-de%20Downloads&color=%2333cc33)
![GitHub Actions Workflow Status](https://img.shields.io/github/actions/workflow/status/archfx/duo-de/sync.yml?style=for-the-badge&label=TrebleDroid%20Sync)

<p align="center">
<img src="images/duo-de-main.gif" alt="drawing" style="width:640px;"/> </p>

## Posture Engine and Dual Modes

With the posture processor engine, both duo1 and duo2 react to various postures. Specifically, the touch configurations and display settings will toggle between left-screen phone mode, right-screen phone mode, and tablet mode based on the hinge position. The hinge gaps can be enabled/disabled through the treble app.
<p align="center">
<img src="images/duo-1.png" alt="drawing" style="height:300px;" /> 
<img src="images/duo-2.png" alt="drawing" style="height:300px;"/> </p>

You can control the active display from quick settings. You can see it in action [here](https://x.com/Archfx/status/1869969450419790257). To add this quick setting tile, use the pencil icon in the notification panel and drag and drop the "Active Screen" tile to your panel.

This ROM switches between tablet mode (first image) and phone mode (second image) when you change the postures or active screen. These modes are optimized (both visually and utility-wise) for each of the situations and the screen's real state. Additionally, it supports peak mode display of device status when the device is unfolded partially.

<p align="center">
<img src="images/tabletmode.png" alt="drawing" style="height:300px;" /> 
<img src="images/phonemode.png" alt="drawing" style="height:300px;"/> </p>

> [!TIP]
> In case your device does not react to tent or ramp mode (landscaped phone mode) by default, you have to enable it from the `Home settings`. When you are in Phone mode, click and hold on the desktop, click `Home settings` on the popup menu, and enable the `Allow home screen rotation` feature. This will enable the launcher to serve the Tent mode and Ramp modes.

### Floating Windows
Floating windowed mode can be enabled/disabled for tablet mode and phone mode separately. To do that, click and hold the desktop, click `Home settings`, and find the settings `Tablet Mode Floating Windows` and `Phone Mode Floating Windows`. 

### Split Windows
You can still launch apps in split window mode (similar to the Stock 12L) using two methods, 

1. Click and hold the application icon, and click the option `Split Screen` from the popup menu
2. Launch the apps first, and use the gesture (or recent apps button on the navigation bar) to access the recent apps window and click `Split`.

Both options will prompt you to open the second application to share the screen.

## Surface Duo 2 Status

DUO-DE works smoothly on both [Surface Duo (Gen1)](https://support.microsoft.com/en-us/surface/surface-duo-1st-gen-features-and-specs-13f2bba9-2b5d-8802-b021-abf26539eef8) and [Surface Duo 2](https://support.microsoft.com/en-us/surface/surface-duo-2-features-01e772a5-3272-4e2f-b0cd-53b5b73e8d21). The additional Surface Duo 2 functionalities, including support for its ultrawide and zoom camera sensors and Surface Pen wireless charging, have been implemented.

The Surface Duo 2 reverse-engineering effort was led by [Ethanol10](https://github.com/Ethanol10), with several significant contributions from [mkostersitz](https://github.com/mkostersitz). Thanks to their efforts, the previously outstanding Duo 2 issues have been resolved. Discussions and technical details about the reverse-engineering work are available [here](https://github.com/Archfx/duo-de/discussions/54).


## Benchmarks

These results are just for reference (for people who enjoy numbers) to compare the CPU and GPU performance of this ROM (latest build) with other operating system options. The best-case numbers of each operating system are included in the graphs.

<div style="text-align: center;">
  
| Comparison | duo-de Results |
|-------|------|
| ![Duo1 CPU](images/duo1-geekbench-6-cpu.svg) | [duo-de cpu](https://browser.geekbench.com/v6/cpu/7437614) |
| ![Duo1 GPU](images/duo1-geekbench-6-gpu.svg) | [duo-de gpu](https://browser.geekbench.com/v6/compute/2640466) |

</div>

## Security

All DUO-DE releases are signed with [release keys](https://source.android.com/docs/core/ota/sign_builds), ensuring protection against malicious OTA updates and unauthorized system application replacements. Additionally, DUO-DE passes [play integrity checks](https://developer.android.com/google/play/integrity/overview), safeguarding against malicious applications. For more details about the security of GSI images like DUO-DE, visit [this post](https://archfx.me/posts/2024/12/androidsecurity/).


## Flashing steps
> [!WARNING]
> **Try this at your own risk and proceed with caution!**

> [!TIP]
> **Please read the release notes before performing OTA updates, Some major updates may require you to wipe user data. I highly recommend you backup your application data!**

> [!CAUTION]
> **BACKUP** your user data before proceeding, it might prompt you to wipe the user data partition depending on your current setup.

Following are the steps to flash this image to your surface duo.

1. Download the release. 
```shell
wget https://github.com/Archfx/duo-de/releases/download/[[version]]/aosp-arm64-ab-gapps-15.0-[[version]].img.xz
```
2. Extract the compressed `*.xz` file to obtain the `*.img`. (Windows users can use something like 7-zip, Linux and Mac users can use either of the following commands with respective commandline utilities).
```shell
tar -xf aosp-arm64-ab-gapps-15.0-[[version]].img.xz #tar utility
```
```shell
gunzip aosp-arm64-ab-gapps-15.0-[[version]].img.xz #gunzip utility
```
3. If you are migrating from Android 12L (stock) follow this step. You need to unlock the bootloader before proceeding. Please pay attention to commands, do not copy and execute the commands blindly.
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

fastboot flash system aosp-arm64-ab-gapps-15.0-[[version]].img
fastboot reboot 
# upon reboot, it will prompt to wipe the user data partition.
```
4. Migrating from 13/14 pixel experience, follow the below steps 
```shell
adb reboot fastboot
fastboot flash system aosp-arm64-ab-gapps-15.0-[[version]].img
fastboot reboot 
```
5. When the device is booted, perform a manual reboot to apply the first-time configurations correctly.
6. Enable the following settings (for enabling the floating windows) from the developer options and perform a manual reboot.  
> - Force activities to be resizable
> - Enable freeform windows
> - Enable non-resizable in multi-window
7. Once you flash a **duo-de** version using the above steps, subsequent updates will be received using OTA. You can check updates using ``settings -> system -> system updates``.
   > If prompted to select the default updater, select `PHH treble updater` for always.
8. Enable the ideal `Treble Settings` as outlined [here](https://github.com/Archfx/duo-de/discussions/81). 
9. If you wish to see future updates and feature improvements, consider _starring_ (★) the project—it motivates the development of new releases!

## Migrating back to 12L

Ethanol10:
I've tested this on a Duo 2, seems to work fairly consistently. You will LOSE all your data when doing this so please backup if you can!

1. Retrieve your Surface recovery image: https://support.microsoft.com/en-us/surface-recovery-image
2. Follow the script below
``` shell
# Boot to fastboot 
adb reboot fastboot

# Delete all partitions that DUO-DE resides on
fastboot delete-logical-partition system_ext_a
fastboot delete-logical-partition system_ext_b
fastboot delete-logical-partition product_a
fastboot delete-logical-partition product_b
fastboot delete-logical-partition system_b
fastboot delete-logical-partition system_a

# Move to Recovery
fastboot reboot recovery
```
3. Navigate using Vol Up/Down to "Apply update from ADB"
4. Run the following commands
```shell
# replace <surface recovery image location> with file location, e.g windows would be C:/platform-tools/
# surface_recovery.zip
adb sideload <surface recovery image location>
```
5. Wipe Data
6. Reboot

Usually, one time isn't enough and you'll end up with a bootloop, follow the steps to get back into recovery to repeat from step 2.
1. Hold Power and as soon as the device vibrates, hold Volume down
2. Use volume buttons to select Recovery Mode and press Power to confirm
3. When the Android logo shows up with No command underneath it, press and hold the power button, then press volume up, and release the power button. It can be a bit finnicky so experiment a little bit (try not to hold the power button for a long time you'll hard reset.)
4. You should be back in recovery, continue earlier steps from step 2.

## Issues
Any issues, please 
[open an issue](https://github.com/Archfx/duo-de/issues/new/choose) with a detailed description. Please use the [discussion](https://github.com/Archfx/duo-de/discussions/new/choose) section for any questions regarding flashing and similar stuff.

## Credits
These people have helped this project in some way or another, so they should be the ones who receive all the credit:

[phhusson](https://github.com/phhusson) [AndyYan](https://github.com/AndyCGYan) [eremitein](https://github.com/eremitein) [kdrag0n](https://github.com/kdrag0n) [Peter Cai](https://github.com/PeterCxy) [haridhayal11](https://github.com/haridhayal11) [sooti](https://github.com/sooti) [Iceows](https://github.com/Iceows) [ChonDoit](https://github.com/ChonDoit) [ponces](https://github.com/ponces) [thai-ng](https://github.com/thai-ng) [farmerbb](https://github.com/farmerbb) [Ethanol10](https://github.com/Ethanol10) [mkostersitz](https://github.com/mkostersitz)


## Disclaimer
THIS REPOSITORY CONTAINS A CUSTOM ANDROID GENERIC SYSTEM IMAGE (GSI) ROM PROVIDED "AS IS," WITHOUT WARRANTY OF ANY KIND. USE, DOWNLOAD, OR INSTALLATION OF THIS SOFTWARE IS **AT YOUR OWN RISK**. THE AUTHORS ARE **NOT LIABLE** FOR ANY DAMAGES, INCLUDING BUT NOT LIMITED TO DEVICE DAMAGE, DATA LOSS, OR OTHER ISSUES RESULTING FROM THE USE OR INSTALLATION OF THIS ROM. INSTALLING CUSTOM ROMS MAY VOID YOUR DEVICE'S WARRANTY AND COULD BRICK YOUR DEVICE, RENDERING IT UNUSABLE. VERIFY COMPATIBILITY WITH YOUR DEVICE BEFORE INSTALLATION. **NO GUARANTEE OF UPDATES, FIXES, OR SUPPORT IS PROVIDED**. THIRD-PARTY SOFTWARE INCLUDED IS SUBJECT TO ITS OWN TERMS. MODIFICATION AND REDISTRIBUTION ARE PERMITTED UNDER THE PROVIDED LICENSE, BUT AUTHORS **DISCLAIM LIABILITY** FOR ISSUES ARISING FROM SUCH ACTIONS. **BY PROCEEDING, YOU ACCEPT THESE TERMS. IF YOU DO NOT AGREE, DO NOT USE THIS FIRMWARE IMAGE.** 






