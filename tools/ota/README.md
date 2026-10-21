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

## Test matrix (run on one Surface Duo 2, GApps variant)
`ota-cases.sh` holds the helpers, `run-cases-*.sh` / `run-case-12*.sh` drive the cases below.

| # | case | result |
|---|---|---|
| 1 | N -> N+1, same variant | PASS: installs, boots N+1, data kept |
| 2 | N+1 -> N+2 (slots alternate a -> b) | PASS: old slot removed after the next boot |
| 3 | wrong `sha256` of the image | PASS: refused, system unchanged |
| 4 | wrong `xz_sha256` of the download | PASS: refused, system unchanged |
| 5 | already up to date (equal date) | PASS: "Your system is up to date", no loop |
| 6 | ota.json without the device's variant | was offered with empty size/url and a generic error; fixed by treble_app patch 0008 (no update offered) |
| 7 | truncated `.xz` | PASS: xz error, system unchanged |
| 8 | network cut during the download | PASS: error dialog, partial slot removed at the next boot |
| 9 | "Delete OTA files" | PASS: warns about data loss, back on the flashed system, no `otaphh` slots |
| 10 | low storage (1.2 GB free) | safe, but the error was generic ("failed to be installed"); patch 0008 checks free space first (4.5 GB) and says so |
| 11 | kill the Updater / reboot mid-install | PASS: boots the old system, no leftovers |
| 12 | a new slot that does not boot | **no rollback**, see below |

## Recovery (a slot that does not boot) - tested
Tested with a valid image whose `/system/bin/init` was removed: it passes both hash checks, the Updater switches slot and
reboots. About 35 s later the device falls back into the bootloader by itself (no key press). It does not return to the
old system on its own.
1. `fastboot reboot fastboot` (fastbootd). `fastboot gsi wipe` does **not** help ("Could not find GSI install"): this OTA is
   not a standard DSU/GSI install.
2. `fastboot erase metadata` and `fastboot reboot`. The pointer to the OTA slot lives in `/metadata/phh/img`, so the device
   boots the flashed `system_b` again. The metadata partition also holds the keys of the encrypted `/data`, so the device then
   asks for a factory reset: **user data is lost**. There is no way around this without keeping the previous slot until the
   first successful boot of the new one (not implemented).
3. Alternatively reflash: `fastboot -S 128M flash system_b <image>`, `fastboot -w`, `fastboot reboot`.
Keep the last known good `.img` from `~/aosp-images/`.

## What is published where
- Test builds: pre-releases on `mkostersitz/duo-de`, never the Archfx repository.
- `config/ota.json` of the fork's branch the devices poll (default `main-16`); the original is in `state/`.
- Note: a GApps image contains Google's apps; publishing one publicly is the same practice as Archfx's releases, but it is
  a licensing question you may want to decide on. The vanilla variant avoids it.
