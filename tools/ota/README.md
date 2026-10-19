# OTA test pipeline (Surface Duo 2, r4 builds)

## How the OTA works
- The Updater (treble_app `UpdaterActivity`) reads `ro.system.ota.json_url`, baked into the image by
  `build.sh` from `GH_REPO` / `OTA_BRANCH` (ours: `https://raw.githubusercontent.com/mkostersitz/duo-de/main-16/config/ota.json`).
  HTTPS only.
- It offers an update when the json `date` is greater than `ro.system.build.date.utc` (compared as strings), and
  only for the variant whose `name` equals `ro.build.flavor` without `-user`/`-userdebug` (e.g. `treble_arm64_bgN`).
- Install: `phh-ota new-slot` creates a gsid backing image `system_otaphh_a|b` (4 GB) under `/data/gsi/phh`, the
  app streams the decompressed `.img.xz` into `/dev/phh-ota`, `phh-ota switch-slot` writes the slot to
  `/metadata/phh/img`, init boots from it. The other slot is deleted after the next successful boot.
  The flashed `system_b` is never modified, "Delete OTA" in the Updater menu goes back to it.
- **Hash verification** (new, in treble_app patch 0003): `ota.json` variants carry `xz_sha256` (the download) and
  `sha256` (the decompressed image). Both are hashed while streaming; a mismatch aborts before the slot switch and the
  running system is untouched. Missing hashes only log a warning (Archfx's json has none).
  It protects against corruption, not against a malicious host: the hashes come from the same place as the image.
  A signature over `ota.json` would be the next step.
- The updater that performs an OTA is the one **already installed**, so hash checking only protects the update
  *after* the build that introduced it.

## Scripts
| script | what it does |
|---|---|
| `publish-ota.sh` | creates a GitHub **pre-release** with the `.img.xz` and replaces `config/ota.json` on a branch of the fork. Reads the build date from the image, hashes both files, saves the previous json in `state/`. Refuses Archfx's repositories. `--dry-run`, `--corrupt-sha256 img|xz`, `--date`, `--no-upload` for the tests below. |
| `restore-ota-json.sh` | puts the saved `config/ota.json` back, `--delete-release TAG` removes a test release and its tag |
| `test-ota.sh` | drives one OTA on the attached Duo through the Updater UI, reboots, verifies the build date and that data survived. `--expect verify-fail` for the negative test, `--preflight-only` just reports what the Updater will see |

The device must be **unlocked and awake** for `test-ota.sh` (it taps through the UI). Logs: `logs/<run id>/`.
raw.githubusercontent.com caches `ota.json` for up to about 5 minutes after a publish.

## Test procedure
1. Baseline: the Duo runs build N (flashed with fastboot or installed by an earlier OTA).
2. Build N+1 (`build.sh`, which now writes the hashes into `config/ota.json`), fetch the `.img.xz`.
3. `./publish-ota.sh --image-xz <N+1>.img.xz --variant treble_arm64_bgN`
4. `./test-ota.sh` (expects success): update installs, reboot, the build date equals the published one, the settings
   and file markers survive.
5. Negative: `./publish-ota.sh --no-upload --tag <same tag> --date <bumped epoch> --corrupt-sha256 img`
   then `./test-ota.sh --expect verify-fail`. The Updater must report a hash mismatch and the build date must not change.
   Needs the installed build to contain the verification (N+1 or later).
6. Clean up: `./restore-ota-json.sh --delete-release <tag>`.

## Test matrix
| case | how | expected |
|---|---|---|
| N -> N+1, same variant (vanilla and GApps) | steps 3-4 | installs, boots N+1, data kept |
| N+1 -> N+2 (slots alternate) | publish another newer build | installs, old slot deleted after boot |
| wrong hash | step 5 | refused, system unchanged |
| "Delete OTA" | Updater menu after an OTA | back on the flashed system |
| already up to date | publish the installed build | no update offered, no loop |
| wrong variant | ota.json without the device's flavor | no size/url, no update |
| interrupted download | airplane mode during the download | error dialog, old slot still boots |
| truncated image | upload a cut-off `.xz` | refused (xz or hash error), system unchanged |
| low storage | fill `/data` | clear error, no half-installed slot |
| reboot during extraction | long-press power mid-download | old slot boots, partial slot removed |
| new slot that does not boot | publish an image that fails early boot | **no automatic rollback**, recover with fastboot |

## Recovery (a slot that does not boot)
Hold Power + Volume Down for the bootloader, then
`fastboot reboot fastboot`, `fastboot -S 128M flash system_b <image>`, `fastboot -w`, `fastboot reboot`
(`-w` also clears `/metadata`, which drops the OTA slot). Keep the last known good `.img` from `~/aosp-images/`.

## What is published where
- Test builds: pre-releases on `mkostersitz/duo-de`, never the Archfx repository.
- `config/ota.json` of the fork's branch the devices poll (default `main-16`); the original is in `state/`.
- Note: a GApps image contains Google's apps; publishing one publicly is the same practice as Archfx's releases, but it is
  a licensing question you may want to decide on. The vanilla variant avoids it.
