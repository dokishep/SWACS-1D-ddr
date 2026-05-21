# RootDDR — Implementation Plan

## 1. Existing SWACS-1D Architecture (Source of Truth)

### 1.1 Buildroot 2025.02.x
The current SWACS-1D workflow clones `buildroot 2025.02.x` from git.buildroot.net.
The `os/configs/swacs1d_defconfig` is the single source of truth for the OS image.

### 1.2 Defconfig highlights (`os/configs/swacs1d_defconfig`)
```
BR2_x86_64=y
BR2_TOOLCHAIN_BUILDROOT_MUSL=y  (musl libc C/C++ toolchain)
BR2_PACKAGE_HOST_RUSTC=y
BR2_LINUX_KERNEL_CUSTOM_VERSION="6.6.30"
+ kernel.fragment: SQUASHFS, FB_EFI, DRM_VIRTIO_GPU, DRM_QXL, DRM_BOCHS, TPM_TPM/CRB
+ X11 + Xorg modular server + Intel/AMD/Nouveau/VESA/fbdev drivers
+ Mesa3D Iris/RadeonSI/Nouveau/GBM
+ SDL3 (X11, KMSDRM, image, ttf, mixer)
+ FFmpeg, ALSA, Opus/Vorbis/FLAC, libva, VA-API intel
+ tpm2-tools, cryptsetup, gptfdisk, openssl, zstd, jq
+ GRUB2 x86_64-efi with custom modules
+ SquashFS root, genimage, post-image signing
```

### 1.3 Board Files (`os/board/swacs1d/`)
| File | Purpose |
|------|---------|
| `genimage.cfg` | GPT disk: EFI(128MB) + root(SquashFS), SCORE+GAME created at runtime |
| `grub.cfg` | Direct boot, zero timeout, root=PARTUUID |
| `kernel.fragment` | 8 kernel config options |
| `post-image.sh` | Sets up EFI dir, copies grub.cfg, `sbsign`s bootloader+kernel |
| `rootfs_overlay/` | Read-only overlay merged into the SquashFS build |

### 1.4 Init Scripts (BusyBox run-level ordering)
| Script | Stage | Behavior |
|--------|-------|---------|
| `S09tpmcheck` | S09 | Probe /dev/tpmrm0 or /dev/tpm0, halt+poweroff if missing |
| `S09tsecureboot` | S09 | Read EFI SecureBoot var, halt+poweroff if disabled |
| `S12warn` | S12 | If GAME partition absent → show X11 provisioning message |
| `S15part` | S15 | If first boot: create SCORE+GAME GPT parts, LUKS encrypt GAME, extract factory provision, TPM-seal key, reboot |
| `S16game` | S16 | Mount SCORE RW (generate 8-digit cabinet ID), opens GAME via TPM-sealed key, mount RO at /opt/game |
| `S90gui` | S90 | Infinite restart loop: `xinit Xorg + start_game.sh → /opt/game/bootstrap` |
| `S91ota` | S91 | Poll `/var/data/update.bundle` every 5 s, verify+decrypt+apply, kill bootstrap |

### 1.5 Supporting Scripts
| Script | Purpose |
|--------|---------|
| `start_game.sh` | xrandr 640×480 @ highest Hz → exec `/opt/game/bootstrap` |
| `usb_trigger.sh` | USB .bundle → verify RSA → decrypt AES → extract → update.sh → killall bootstrap |
| `ota_trigger.sh` | Background daemon polling `/var/data/update.bundle` continuously |
| `init_keys.sh` | Generate RSA+AES test keys, UEFI Secure Boot db.key/db.crt/db.der |
| `make_bundle.sh` | tar → zstd → AES-256-CBC → manifest.json → RSA sign → .bundle |
| `make_factory_provision.sh` | Pack factory_payload/keys → factory_provision.tar.zst |
| `bootstrap (Rust/SDL3)` | Input diagnostic / test harness; window "SWACS-1D Input Test" |

### 1.6 CI Workflow (`.github/workflows/build.yml`)
GitHub Actions on push to main:
1. Install build deps + musl cross toolchain
2. Build & sign Rust bootstrap, create factory provision (v1.00) and update bundle (v1.01)
3. `git clone buildroot 2025.02.x`, copy board files + defconfig in
4. `make swacs1d_defconfig`, `make -j2` → swacs1d.img
5. Compress to `.img.xz`, upload artifact, publish GitHub Release

---

## 2. RootDDR — Requirements Mapping

| Requirement | Notes |
|-------------|-------|
| **Buildroot 2025.02.x LTS** | Uses `2025.02.x` branch |
| **MAME for Konami System 573 DDR** | Add MAME to defconfig; config for -573 mixes, event mode, save-state loading |
| **ddr-picker / pegasus-fe** | ddr-picker is Windows/AutoHotkey; port the concept to Linux using pegasus-fe (C++/Qt, SDL2 backend) + custom grid-micro theme + game descriptor files |
| **Input mapping wizard (first boot)** | New `S10inputwiz` script; SDL2 GameController configurator; persist to `/var/data/input.conf` |
| **USB memory card emulation (PS1-style)** | Kernel config: USB Storage gadget + `g_mass_storage` on OTG port; Buildroot: gadgetfs / composite configfs |
| **Boot/resume system** | Kernel: CONFIG_PM, CONFIG_PM_SLEEP; systemd-suspend or busybox sysfs resume; S90gui watchdog pattern already present |
| **X11 lightweight runtime** | Keep Xorg stripped to essentials; replace full Mesa with just what MAME needs |
| **Latency optimisations** | Real-time CPU governor, CPU isolation (isolcpus), low-latency ALSA, HID polling rate, kernel PREEMPT_RT |

---

## 3. Bead Architecture

All beads belong under `os/board/rootddr/` and `os/configs/rootddr_defconfig`.

### Bead 1 — Baseboard: Buildroot 2025.02.x LTS
**Files changed:** `os/configs/rootddr_defconfig`, `os/board/rootddr/genimage.cfg`, `os/board/rootddr/grub.cfg`, `os/board/rootddr/kernel.fragment`, `os/board/rootddr/post-image.sh`
**Tasks:**
- Create `os/board/rootddr/` (copy `swacs1d` as starting point, rename everywhere)
- Buildroot clone URL remains `2025.02.x` (no change needed)
- Review defconfig options: bring forward all SWACS-1D settings, drop what is DDR-specific
- Augment `kernel.fragment` with DDR-specific additions: CONFIG_USB_GADGET, CONFIG_USB_CONFIGFS, CONFIG_USB_G_MASS_STORAGE, CONFIG_USB_F_MASS_STORAGE, CONFIG_HIDRAW, CONFIG_UINPUT, CONFIG_INPUT_EVDEV, CONFIG_SND_HDA_INTEL, CONFIG_SND_ALSA_SIM, CONFIG_SND_USB_AUDIO, CONFIG_SND_OSSEMUL (if needed), CONFIG_TIMERFD, CONFIG_EPOLL, CONFIG_NO_HZ_FULL
- Update genimage.cfg: add `opt` partition (opt RW ext4 for /opt/game style emulation in DDR context)
- Keep GRUB config close to SWACS-1D but add `reboot=b` kernel param for fast-reboot support
- Update `post-image.sh`: keep sbsign logic, add kernel cmdline injector hook for latency params

### Bead 2 — MAME: Konami System 573 DDR Package
**Files changed:** `os/configs/rootddr_defconfig`, `os/board/rootddr/rootfs_overlay/`
**Tasks:**
- Add `BR2_PACKAGE_MAME=y` to defconfig (Buildroot 2025.02.x has MAME package)
- Add MAME ConfigFragment (`os/board/rootddr/mame.fragment`) enabling `--target gnu-linux`, with `CONFIG_SYSTEM573=y`, `CONFIG_KCHMPS=y`, `CONFIG_DDR=y`, audio drivers for ALSA+PortAudio
- Add audio latency patch layer to MAME build (patch rate-limit async sound, reduce audio buffer)
- Add `mame-system573-save-states/` directory to rootfs_overlay (pre-built `o` state per game matching ddr-picker convention)
- Add `/opt/game/launcher.sh` skeleton in rootfs_overlay; will be filled by Bead 4

### Bead 3 — pegasus-fe Frontend
**Files changed:** Buildroot external tree `package/pegasus-fe/` overlay in `os/board/rootddr/external/`, `os/configs/rootddr_defconfig`
**Tasks:**
- Create Buildroot external package `os/board/rootddr/external/pegasus-fe/Config.in` (depends on Qt5 or Qt6 widgets + SDL2)
- Create `.mk` file: clone `https://github.com/mmatyas/pegasus-frontend` at latest stable
- Create overlay defconfig additions for pegasus assets (micro grid theme, DDR metadata files)
- Add `BR2_PACKAGE_PEGASUS_FE=y` and dependency chain to defconfig
- Add `/opt/home/share/pegasus/` skeleton in rootfs_overlay (config/, themes/, games/)
- Create DDR video game metadata set matching ddr-picker asset corpus: `DDR1MIX`, `DDR2MIX`, `DDR3RD`, …, `DDRX`, `DDR2013`, `DDR2014`, `DDRACE`
- Add Kodi-addon-style launcher scripts: each game → `pegasus-run <game>` → `mame <machine> -state o`

### Bead 4 — Input Mapping Wizard (First Boot)
**Files changed:** `os/board/rootddr/rootfs_overlay/etc/init.d/S10inputwiz`, `os/board/rootddr/external/input-wizard/`
**Tasks:**
- Buildroot external package `os/board/rootddr/external/input-wizard/` (Rust/SDL3 binary, similar tech to existing `bootstrap`)
- SDL2 GameController API wizard: step through P1 pad, P2 pad, service buttons
- Run on first boot if `/var/data/input.conf` absent (new Bead 1 overlay run-parts file)
- Write SDL2 GameController mappings to `/var/data/input.conf`
- Input wizard UI: SDL3-rendered "Press button for ← Up" → axis value capture → save as `SDL_GAMECONTROLLERCONFIG=...` env export file
- `S10inputwiz` script: checks for config, if missing runs `/usr/local/bin/input-wizard`, persists mapping into `/etc/profile.d/input_wizard.sh`

### Bead 5 — USB Memory Card Emulation (PS1-Style)
**Files changed:** `os/configs/rootddr_defconfig`, `os/board/rootddr/kernel.fragment`, `os/board/rootddr/rootfs_overlay/`
**Tasks:**
- Kernel fragment additions: CONFIG_USB_GADGET, CONFIG_USB_CONFIGFS, CONFIG_USB_G_MASS_STORAGE, CONFIG_USB_G_HID
- Add `br2-external` package for gadget setup script: `/usr/local/bin/gadget-init.sh`
  - Create configfs gadget: composite → HID (keyboard) + Mass Storage → binding to UDC device
  - Present as PS1 memory card image file via backing file

- On first boot: create blank 128 KB memory card image (`/var/data/memcard.bin`) formatted as PS1 `.MCR`
- Create tool `/usr/local/bin/memcard-dump.sh` / `memcard-restore.sh` to pull/push card save data via OTG
- Note: Single USB-C OTG port must be shared between game data and memory card; the gadget configfs approach allows hot-swap on same physical port if user removes mass-storage function and re-enables  

### Bead 6 — Boot/Resume & Watchdog
**Files changed:** `os/configs/rootddr_defconfig`, `os/board/rootddr/kernel.fragment`, `os/board/rootddr/external/watchdog/`
**Tasks:**
- Kernel fragment: CONFIG_PM=y, CONFIG_PM_SLEEP=y, CONFIG_WAKELOCK=y (if available)
- Power management: set governor to performance via init.d script
- Pin /opt/game/state/last_game.txt on resume: first boot wizard stores lock file; S90gui reads it → passes `mame --last-game` argument
- Buildroot external package `watchdog`: userspace daemon `rootddr-reaper` (Rust binary)
  - Monitors `/opt/game/bootstrap` PID
  - If process dies: stores score dump, resume with `mame <last_game> -state o`
  - Optional: panic on repeated crash loop → fall over to `input-wizard` or error screen
- Extend `S90gui` from SWACS-1D: replace hardcoded `/opt/game/bootstrap` exec line, add `--resume` flag parsing

### Bead 7 — X11 Runtime Optimization
**Files changed:** `os/configs/rootddr_defconfig`, `os/board/rootddr/rootfs_overlay/`
**Tasks:**
- Expand `rootfs_overlay` X11 setup:
  - Add lightweight compositor config (xcompmgr or picom minimal) — OR disable entirely for zero-latency direct scanout
  - Add `xinput` rules to force evdev → uinput passthrough (no latency adding layers)
  - Add `/etc/X11/xorg.conf.d/60-input-latency.conf`: `Option "Ignore" "true"` on all non-essential inputs
  - Add `/etc/X11/xorg.conf.d/10-evdev.conf`: `MatchIsKeyboard "on"`, `Driver "evdev"`, set HW polling minimum
  - Disable DPMS from Xorg flags (already done in SWACS: `-dpms`)
- Replace Mesa build to only keep i965/iris Gallium (drop radeonsi/nouveau if DDR targets Intel-only; keep both for compatibility)
- Add `BR2_PACKAGE_SDL3_TTF=y` addon for input wizard text rendering
- Remove from SWACS base (not needed): graphene-clang, rust full std (keep Rust for MAME binary if available, else remove)

### Bead 8 — Latency Optimizations (Kernel + ALSA + CPU)
**Files changed:** `os/board/rootddr/kernel.fragment`, `os/configs/rootddr_defconfig`, `os/board/rootddr/rootfs_overlay/etc/init.d/S08realtime`
**Tasks:**
- New `S08realtime` init script (runs before S09tpmcheck if latency takes priority — or after; TPM check is security-gating):
  - Set CPU governor to `performance`: `for f in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do echo performance > $f; done`
  - CPU isolation: add `isolcpus=2,3` (assuming 4-core min x86; derive from `/proc/cpuinfo`)
  - Disable hyper-threading siblings if board supports: `echo 1 > /sys/devices/system/cpu/smt/control`
  - Drop caches: `echo 3 > /proc/sys/vm/drop_caches`
  - IRQ balancing: pin IRQs to non-isolated core
- New kernel fragment additions: CONFIG_HZ_1000=y, CONFIG_PREEMPT=y, CONFIG_IRQ_FORCED_THREADING=y
- Add `BR2_PACKAGE_ALSA_UTILS_ALSACTL_INITSCRIPT=y` for ALSA low-latency profile
- Add `BR2_PACKAGE_RT_TESTS=y` for latency verification build time
- ALSA PCM config: `/etc/asound.conf` direct plug with `periods = 3`, `period_size = 128`, `buffer_size = 256` for MAME

### Bead 9 — Authoring: Factory Pack + Bundle Script Update
**Files changed:** `authoring/init_keys.sh`, `authoring/make_factory_provision.sh`, `authoring/make_bundle.sh`, `authoring/example_update.sh`, `.github/workflows/build.yml`
**Tasks:**
- Roll v1.00→v2.00 factory pack: add `pegasus/config/settings.txt`, `launcher.sh`, `memcard.bin.empty`
- Update example_update.sh to include DDR game-specific steps (score dump, highscore backup)
- Push new image assembly naming: `rootddr.img` → `rootddr.img.xz`
- GitHub Actions rename: artifact "RootDDR-Image", release tag `rootddr-v2.0.N`
- Add KBuild step for input-wizard + watchdog Rust crates (cargo build --release, target x86_64-unknown-linux-musl)

---

## 4. Buildroot 2025.02.x LTS Notes

### Differences from 2025.02.x
| Area | 2025.02.x | Notes |
|------|-----------|-------|
| Clone URL | `git.buildroot.net/buildroot` (2025.02.x branch) | Use 2025.02.x branch |
| SDL3 | Available in 2025.02.x | Same |
| MAME | Available | Same |
| Musl toolchain | Manual download | Available as BR2_TOOLCHAIN_BUILDROOT_MUSL |

### CI Workflow Changes
```yaml
# Old
git clone --depth 1 --branch 2025.02.x https://git.buildroot.net/buildroot
# Old artifact names
 name: SWACS-1D-Image
 name: SWACS-1D-Provisioning-And-Updates

# New
git clone --depth 1 --branch 2025.02.x https://git.buildroot.net/buildroot
cp -r os/board/rootddr/* buildroot/board/rootddr/
cp os/configs/rootddr_defconfig buildroot/configs/
make rootddr_defconfig
# New artifact names
 name: RootDDR-Image
 name: RootDDR-Provisioning-And-Updates
```

---

## 5. ddr-picker Integration — Linux Port Rationale

`ddr-picker` by evanclue is a Windows/AutoHotkey project using pegasus-fe on top of a custom MAME build. The following concepts are ported:

| ddr-picker concept | RootDDR implementation |
|--------------------|----------------------|
| `pegasus-fe.exe` + `themes/micro/` | `pegasus-fe` Qt6 build + imported micro-grid theme assets |
| `settings.txt` (Pegasus config) | `/opt/pegasus/config/settings.cfg` in rootfs_overlay |
| `mame.exe <machine> -state o` | `/opt/game/launcher.sh <machine>` → `mame <machine> -state o` |
| `kill_pegasus.bat` before game | S90gui restart-loop handles this natively (xinit restarts Xorg) |
| DDR metadata `.pegasus.txt` files | Same format → imported into rootfs_overlay `/opt/pegasus/metadata/` |
| `assets.zip` (DDR logos) | Same assets → shipped in factory pack |
| `reset-button.ahk` | F12 handled by `ddr-input-wizard` + S90gui restart |
| MAME pack + save-states | Stored in GAME partition; include compressed save-state bundle in factory_provision.tar.zst |

---

## 6. Boot Sequence — RootDDR

```
BIOS/UEFI
  └─ SecureBoot check (S09tsecureboot)
       └─ TPM 2.0 check (S09tpmcheck)
            └─ S12warn — GAME partition absent → provisioning message
                 └─ S15part — first boot only: create partitions, factory provision, TPM seal, reboot
                      └─ [reboot]
                           └─ S16game: mount SCORE, TPM-unseal+GAME mount
                                └─ S08realtime: CPU governor / isolation
                                     └─ S10inputwiz: if no input.conf → SDL3 wizard
                                          └─ S90gui: xinit → Xorg + start_game.sh
                                               └─ start_game.sh: xrandr 640×480 → exec pegasus-fe
                                                    └── [selected] exec mame <machine> -state o
                                          └─ S91ota: background OTA poller
```

---

## 7. Partition Map (RootDDR, from genimage.cfg)

| # | Label | Type | Size | Mount | Purpose |
|---|-------|------|------|-------|---------|
| 1 | ESP | FAT32 | 128 M | EFI | GRUB + kernel + initrd |
| 2 | root | SquashFS | remainder/2 | / | Read-only OS image |
| 3 | SCORE | ext4 | 128 M | /var/data | High scores, cabinet ID, input.conf, bundles |
| 4 | GAME | LUKS+ext4 | remainder | /opt/game | Encrypted game data + pegasus + keys + memcard.img |

---

## 8. Key Files Summary (RootDDR additions)

```
os/
  configs/
    rootddr_defconfig              ← replaces swacs1d_defconfig
  board/
    rootddr/
      genimage.cfg
      grub.cfg
      kernel.fragment              ← adds gadget, HID, RT, MAME
      post-image.sh
      mame.fragment                ← MAME config fragment
      external/
        pegasus-fe/                 ← Buildroot external package
        input-wizard/               ← Buildroot external package (Rust/SDL3)
        watchdog/                   ← Buildroot external package (Rust)
      rootfs_overlay/
        etc/
          init.d/
            S08realtime             ← CPU governor / isolation
            S10inputwiz             ← first-boot SDL3 input wizard
          asound.conf               ← ALSA low-latency PCM profile
          profile.d/
            input_wizard.sh         ← SDL_GameControllerConfig export
        usr/
          bin/
            start_pegasus.sh        ← xrandr → pegasus-fe
            memcard-dump.sh
            memcard-restore.sh
          local/
            bin/
              input-wizard          ← SDL3 binary (Beep press → mapping)
              ddr-reaper            ← Process watchdog + state resume
              gadget-init.sh        ← USB gadget (mass-storage + HID)
        opt/
          pegasus/                  ← config/, themes/, metadata/, games/
          game/                     ← mame/, launcher.sh, state/
        var/
          data/                     ← .gitkeep; memcard.bin created at boot
        mnt/
          usb/                      ← USB update bundle staging

authoring/
  init_keys.sh                     ← v2.0: add factory content signing
  make_factory_provision.sh
  make_bundle.sh
  example_update.sh                ← add DDR score dump + MAME state backup

.github/
  workflows/
    build.yml                      ← rename artifacts, add rootddr defconfig
```

---

## 9. Development Order

1. **Bead 1** (baseboard) → clone `os/board/rootddr/` from swacs1d, rename; verify CI builds
2. **Bead 2** (MAME) → add to defconfig; verify MAME boots; add save-state loading to launcher
3. **Bead 7** (X11 runtime) → thin Xorg profile, confirm 640×480 no-compositor boot before game layer
4. **Bead 8** (latency) → S08realtime + kernel fragment; measure with rt-tests
5. **Bead 3** (pegasus-fe frontend) → build pegasus-fe, set up metadata, verify UI
6. **Bead 4** (input wizard) → SDL3 wizard binary + S10inputwiz; first-boot flow
7. **Bead 5** (USB memory card) → gadget-init.sh + memcard tools
6. **Bead 6** (boot/resume) → ddr-reaper watchdog, last-game resume
8. **Bead 9** (authoring) → factory pack v2.00, update CI workflow
