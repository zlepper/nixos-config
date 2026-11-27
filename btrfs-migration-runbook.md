# Runbook: migrate rhdh-work-desktop to btrfs

Move `/`, `/nix` and `/home` from ext4 to one LUKS-encrypted btrfs pool across both NVMe drives. The new SATA SSD becomes swap plus an empty `/data`. Everything happens on the live system, with no USB stick.

## Decisions
| | |
|---|---|
| Pool | data `single`, metadata `raid1`, ~1.9 TB usable. Losing either NVMe loses everything (accepted). |
| Compression | `compress=zstd:1,noatime` on all btrfs mounts |
| New LUKS | `allowDiscards`, `bypassWorkqueues`; same passphrase everywhere, so one prompt at boot |
| Swap | 32 GiB LUKS on SATA p1 (stays LUKS for Intune), with zswap in front of it. The 32G-capped lowprio/claude/codex scopes swap actively, so most swap-ins come from compressed RAM. |
| Old `/data` | Copy `temp-backup-of-kde/` to `~`, drop `camp/` |
| Samsung p3/p4 | Deleted at the end, and p2 grows over them. p4 is never added to the pool, because it's on the same physical disk as p2. |

## Disks
| | by-id | Now | End |
|---|---|---|---|
| Samsung | `nvme-SAMSUNG_MZVL21T0HCLR-00BL7_S64PNE0R112892` | p1 ESP · p2 `/` · p3 swap · p4 `/data` | p1 ESP · p2 pool (grown) |
| WD | `nvme-WDC_PC_SN730_SDBQNTY-1T00-1001_20506T459605` | p1 `/home` | p1 pool |
| SATA | `ata-…` (step 0) | — | p1 swap · p2 `/data` (holds root during steps 1–3) |

The Samsung partitions are physically in the order p1, p2, p3, p4, with p4 at the end of the disk.

Old LUKS containers:
- `d26f5db3-adad-472d-8244-27a2e65bb270`: root (Samsung p2)
- `ad3fca90-eebe-4e31-96c4-46d3f1b6e4f1`: home (WD p1)
- `7da2e744-45ca-4d4b-a58e-edab3f92b966`: `/data` (Samsung p4)
- `41434903-08ad-473f-bd3d-e8e01ef1762e`: swap (Samsung p3)

## Rules
The initrd is systemd's (the 26.05 default). It creates one systemd-cryptsetup unit per `boot.initrd.luks.devices` entry. The first passphrase you type is cached and tried on all of them, so identical passphrases give one prompt. btrfs udev rules hold back the root mount until every pool member is unlocked. An entry whose device doesn't exist waits for the device timeout, and the boot fails.

1. **Before a device joins the pool**, add its LUKS entry and run `nixos-rebuild boot`.
2. **Before wiping a container**, remove its LUKS entry, and only once nothing in the config uses it.
3. **No `nixos-rebuild switch`** between a hand-swapped mount and the next reboot. Use `boot` only.
4. **Older generations stop booting** once the pool's set of devices changes. The only rollback is to the old root, and only until 2a.

LUKS entries in the config (`+` added, `–` removed):

| After | old swap | old root | old home | old data | SATA p1 | SATA p2 | new Samsung p2 | new WD |
|---|---|---|---|---|---|---|---|---|
| start | ✓ | ✓ | ✓ | ✓ | | | | |
| 1 | – | – | ✓ | ✓ | + | + | | |
| 2a | | | ✓ | ✓ | ✓ | ✓ | + | |
| 2c | | | – | ✓ | ✓ | ✓ | ✓ | |
| 3 | | | | ✓ | ✓ | ✓ | ✓ | + |
| 4 | | | | – | ✓ | ✓ (`/data`) | ✓ | ✓ |

## Conventions
- **Keep this runbook open off the machine** (phone or another computer). KDE is logged out in 1.4 and 2c, and `/home` gets swapped out underneath.
- **Every root shell:** run `nix-shell -p psmisc gptfdisk cloud-utils smartmontools` first. `/etc/bashrc` would otherwise turn it into fish. Check with `echo $BASH_VERSION`.
- **Migration tmux:** after **every** reboot, recreate it from a desktop terminal with `cd / && sudo systemd-run --scope --unit=migrate-tmux tmux new -s migrate`, then run the nix-shell line inside it. Running it in its own scope keeps it out of your user session. Run all long operations (2b, 3, 5) in it. Reattach with `sudo tmux attach -t migrate`.
- **Start every block with `source /root/btrfs-migration.env`.** New UUIDs get appended to that file. It also defines `$FLAKE` (`/home/rasmus/nixos-config#rhdh-work-desktop`) and `$INH`, a `systemd-inhibit` wrapper that keeps the machine from sleeping during long operations.
- **`# expect:` is an assertion.** If the output differs, stop.
- **Live rsync passes** may exit with 24. **Final passes** must exit with 0; if one exits with 23 or 24, check `--log-file`, then re-run it once.
- **Config edits:** LUKS entries are written as `boot.initrd.luks.devices."luks-<X>" = luks "<X>";`.
- **New LUKS containers** are always created with `btrfs-migration-luks-format.sh`. It checks that the passphrase unlocks every existing container, formats and opens the new ones, appends their UUIDs to the env file and prints the config lines.

---

## Step 0: preparation
1. **Commit or revert `flake.lock`.** Commit the prep changes in `hardware/work-desktop.nix` too. After that, make no other config changes until step 6.
2. **Rebuild and reboot into the current config.** You've been up since 28 Oct, so the default generation's kernel and NVIDIA driver have never booted. This reboot also activates the prep changes already in the config: the `luks`/`btrfsOpts` helpers, discards and workqueue bypass on the existing LUKS devices, zswap, and btrfs autoScrub. Check them:
   ```sh
   cat /sys/module/zswap/parameters/enabled                        # expect: Y
   sudo dmsetup table | grep -c allow_discards                     # expect: 4
   ```
3. **Backups:**
   - **CockroachDB volume `deploymentmanager_cockroach`** (irreplaceable). A restore-tested backup from 2026-11-26 is in OneDrive. If the DB is written again before step 2, take a new one: stop both containers, `podman volume export`, then restore-test it.
   - Push your branches (see the unpushed-work report).
4. **Cleanup:** done. Home was down to 410G on 2026-11-26, which leaves plenty of room for step 2 (root 244G + home on ~1.23 TiB). Podman now holds only the DeploymentManager CockroachDB. **Never** run `podman container prune`, `volume prune` or `system prune`: the cockroach volume is attached only to stopped containers, so a prune deletes it.
5. **Smoke test: podman on btrfs on LUKS.** This mirrors the production stack. The full kind check happens after 2c.
   ```sh
   truncate -s 40G /data/t.img && head -c 64 /dev/urandom > /dev/shm/t.key
   sudo cryptsetup luksFormat -q --key-file /dev/shm/t.key /data/t.img
   sudo cryptsetup open --key-file /dev/shm/t.key /data/t.img ttest && sudo mkfs.btrfs -q /dev/mapper/ttest
   sudo mkdir -p /mnt/ttest && sudo mount -o compress=zstd:1,noatime /dev/mapper/ttest /mnt/ttest && sudo chown rasmus:users /mnt/ttest
   printf '[storage]\ndriver = "overlay"\ngraphroot = "/mnt/ttest/graph"\nrunroot = "/run/user/1000/ttest-run"\n' > /mnt/ttest/storage.conf
   env CONTAINERS_STORAGE_CONF=/mnt/ttest/storage.conf KIND_EXPERIMENTAL_PROVIDER=podman kind create cluster --name btrfs-test
   kubectl --context kind-btrfs-test get nodes                     # expect: Ready
   env CONTAINERS_STORAGE_CONF=/mnt/ttest/storage.conf KIND_EXPERIMENTAL_PROVIDER=podman kind delete cluster --name btrfs-test
   env CONTAINERS_STORAGE_CONF=/mnt/ttest/storage.conf podman unshare rm -rf /mnt/ttest/graph
   sudo umount /mnt/ttest && sudo cryptsetup close ttest && rm /data/t.img /dev/shm/t.key
   ```
6. **Root password:** run `sudo passwd -S root` and note whether it shows `L` (locked). If it does, set a temporary password with `sudo passwd root`. Test logging in on Ctrl+Alt+F3. Keep it until step 6.
7. **Rescue shell:** `boot.initrd.systemd.emergencyAccess` is `false`, so a failed initrd boot gives no shell, and there is no USB stick. Step 1.3 therefore sets it to `true` for the duration of the migration (step 6 reverts it). Once the system has booted, emergency mode asks for the root password.
8. **Power off and install the SATA SSD.** Then:
   ```sh
   ls -l /dev/disk/by-id/ | grep ata-                              # disk link without -partN
   lsblk -o NAME,SIZE,MODEL,FSTYPE                                 # expect: ~477G, nothing you need
   nix-shell -p smartmontools --run "sudo smartctl -a /dev/disk/by-id/ata-…"   # expect: PASSED
   printf 'SATA=/dev/disk/by-id/ata-…\nFLAKE=/home/rasmus/nixos-config#rhdh-work-desktop\nINH="systemd-inhibit --what=sleep:idle:shutdown --why=btrfs-migration"\n' | sudo tee /root/btrfs-migration.env
   ```

---

## Step 1: root → SATA

### 1.1 Partition and format (in the migration tmux)
```sh
source /root/btrfs-migration.env && [ -n "$SATA" ] && echo ok         # expect: ok
sgdisk --zap-all "$SATA" && sgdisk -n1:0:+32G -t1:8309 -c1:swap -n2:0:0 -t2:8309 -c2:pool "$SATA" \
  && udevadm settle && lsblk -o NAME,SIZE,PARTLABEL "$SATA"           # expect: p1 32G swap, p2 ~445G pool
```
Run the LUKS script on its own; it prompts for `WIPE` and the passphrase:
```sh
bash /home/rasmus/nixos-config/btrfs-migration-luks-format.sh SWAP_LUKS="$SATA-part1" SATA_LUKS="$SATA-part2"
```
Then, only if it ended with the config lines:
```sh
source /root/btrfs-migration.env && [ -n "$SWAP_LUKS" ] && [ -n "$SATA_LUKS" ] && echo ok   # expect: ok
mkswap "/dev/mapper/luks-$SWAP_LUKS" && SWAP_UUID=$(blkid -p -s UUID -o value "/dev/mapper/luks-$SWAP_LUKS") \
  && mkfs.btrfs -L nixos "/dev/mapper/luks-$SATA_LUKS" && POOL=$(blkid -p -s UUID -o value "/dev/mapper/luks-$SATA_LUKS") \
  && printf 'SWAP_UUID=%s\nPOOL=%s\n' "$SWAP_UUID" "$POOL" >> /root/btrfs-migration.env
cat /root/btrfs-migration.env                                         # expect: all values non-empty

mkdir -p /mnt/pool /mnt/new
mount -o subvolid=5,compress=zstd:1,noatime "/dev/mapper/luks-$SATA_LUKS" /mnt/pool
btrfs subvolume create /mnt/pool/@ /mnt/pool/@nix /mnt/pool/@home
mount -o subvol=@,compress=zstd:1,noatime "/dev/mapper/luks-$SATA_LUKS" /mnt/new && mkdir -p /mnt/new/nix
mount -o subvol=@nix,compress=zstd:1,noatime "/dev/mapper/luks-$SATA_LUKS" /mnt/new/nix
```

### 1.2 Live copy (keep working)
`/nix` is copied separately: `-x` would follow the `/nix/store` bind mount, because it's on the same device. `/tmp` is copied too, because it holds git worktrees.
```sh
RS="rsync -aHAXS --numeric-ids --info=progress2"
$INH $RS -x --exclude=/nix --exclude=/lost+found --exclude=/root/.cache / /mnt/new/ ; echo "exit $?"   # expect: 0/24
$INH $RS /nix/ /mnt/new/nix/ ; echo "exit $?"                                                         # expect: 0/24
```

### 1.3 Config (build only)
`hardware/work-desktop.nix` already has the `luks` and `btrfsOpts` helpers in its `let` block. Add `pool = "/dev/disk/by-uuid/<POOL>";` there. In the body:
- Replace `fileSystems."/"` with:
  ```nix
  fileSystems."/"    = { device = pool; fsType = "btrfs"; options = [ "subvol=@" ] ++ btrfsOpts; };
  fileSystems."/nix" = { device = pool; fsType = "btrfs"; options = [ "subvol=@nix" ] ++ btrfsOpts; };
  ```
- Remove the LUKS entries `luks-d26f5db3-…` and `luks-41434903-…`.
- Add LUKS entries for `<SATA_LUKS>` and `<SWAP_LUKS>`.
- Set `swapDevices = [ { device = "/dev/disk/by-uuid/<SWAP_UUID>"; discardPolicy = "both"; } ];`.

Also add `boot.initrd.systemd.emergencyAccess = true;` (rescue shell if the initrd fails; temporary until step 6).

In `gc.nix`, change `automatic = true` to `automatic = false`. This is temporary until step 6.

```sh
cd ~/nixos-config && nixos-rebuild build --flake .#rhdh-work-desktop
grep -E ' (/|/nix) |swap' result/etc/fstab                         # expect: <POOL> subvol=@ / @nix; <SWAP_UUID> swap
```
Only build here, don't run `boot`. The boot default switches inside 1.4, so an unexpected reboot before then still boots the old root.

### 1.4 Final sync + reboot (downtime ~10–15 min)
Log out of KDE. On Ctrl+Alt+F3, log in as root, run the nix-shell line, then `tmux attach -t migrate`.
```sh
source /root/btrfs-migration.env && [ -n "$POOL" ] && echo ok         # expect: ok
systemctl isolate multi-user.target
loginctl terminate-user rasmus; systemctl stop user@1000.service
umount -l /root/.cache/doc 2>/dev/null
systemctl stop nix-gc.timer intune-daemon microsoft-identity-device-broker tailscaled cups \
  libvirtd.socket libvirtd-ro.socket libvirtd-admin.socket libvirtd.service
nixos-rebuild boot --flake "$FLAKE"                                   # boot default → new root
systemctl stop nix-daemon.socket nix-daemon.service
RS="rsync -aHAXS --numeric-ids --info=progress2 --delete"
$RS -x --exclude=/nix --exclude=/lost+found --exclude=/root/.cache --log-file=/root/rsync-root.log / /mnt/new/ ; echo "exit $?"   # expect: 0
$RS --log-file=/root/rsync-nix.log /nix/ /mnt/new/nix/ ; echo "exit $?"                                                        # expect: 0
[ "$(readlink /mnt/new/nix/var/nix/profiles/system)" = "$(readlink /nix/var/nix/profiles/system)" ] && echo same   # expect: same
sync && systemctl reboot
```
To **abort** before rebooting, put the old default back:
```sh
nix-env -p /nix/var/nix/profiles/system --rollback && /nix/var/nix/profiles/system/bin/switch-to-configuration boot
```

### 1.5 Verify (recreate the migration tmux first)
```sh
for m in / /nix /home /data; do findmnt -no TARGET,SOURCE,FSTYPE -M $m; done   # expect: / /nix btrfs [/@] [/@nix]; /home ext4; /data btrfs (p4)
sudo btrfs filesystem show /                    # expect: 1 device
swapon --show=NAME --noheadings | xargs -n1 lsblk -sno NAME   # expect: chain ends in the SATA disk's part1
systemctl --failed
```
Also check that Intune still shows encrypted, and that the desktop and Tailscale work.

**Rollback (until 2a):** choose the previous generation at boot. Everything written to root since 1.4 is lost, including the git worktrees in `/tmp`. Wait a day before 2a.

---

## Step 2: home → pool

### 2a. Samsung p2 joins the pool (point of no return for the old root)
```sh
source /root/btrfs-migration.env
SAMSUNG=/dev/disk/by-id/nvme-SAMSUNG_MZVL21T0HCLR-00BL7_S64PNE0R112892 && echo "SAMSUNG=$SAMSUNG" >> /root/btrfs-migration.env
cryptsetup luksUUID "$SAMSUNG-part2"                               # expect: d26f5db3-adad-472d-8244-27a2e65bb270
cryptsetup status luks-d26f5db3-adad-472d-8244-27a2e65bb270        # expect: inactive
bash /home/rasmus/nixos-config/btrfs-migration-luks-format.sh P2_LUKS="$SAMSUNG-part2" && source /root/btrfs-migration.env
```
Config: add a LUKS entry for `<P2_LUKS>`. Then:
```sh
nixos-rebuild boot --flake "$FLAKE" && btrfs device add "/dev/mapper/luks-$P2_LUKS" / \
  && btrfs filesystem show /                                       # expect: 2 devices
```

### 2b. Live copy of home (in tmux; keep working)
```sh
source /root/btrfs-migration.env
mountpoint -q /mnt/pool || mount -o subvolid=5,compress=zstd:1,noatime "/dev/disk/by-uuid/$POOL" /mnt/pool
$INH rsync -aHAXS --numeric-ids -x --info=progress2 --exclude=/lost+found /home/ /mnt/pool/@home/ ; echo "exit $?"   # expect: 0/24
```
Run it again just before 2c and time that run; the downtime will be about the same.

Config change (build only):
- set `fileSystems."/home" = { device = pool; fsType = "btrfs"; options = [ "subvol=@home" ] ++ btrfsOpts; };`
- remove the old `/home` block and `luks-ad3fca90-…`

Then run `nixos-rebuild build --flake /home/rasmus/nixos-config#rhdh-work-desktop`.

### 2c. Switchover (downtime ~5–15 min)
Log out of KDE. On Ctrl+Alt+F3, log in as root, run the nix-shell line, then `cd /`. Don't use tmux here: its shell may hold `/home`.
```sh
source /root/btrfs-migration.env && [ -n "$POOL" ] && echo ok      # expect: ok
loginctl terminate-user rasmus; systemctl stop user@1000.service
sleep 3; fuser -vm /home                                           # expect: only the "kernel mount /home" line
mountpoint -q /mnt/pool || mount -o subvolid=5,compress=zstd:1,noatime "/dev/disk/by-uuid/$POOL" /mnt/pool
rsync -aHAXS --numeric-ids -x --delete --info=progress2 --log-file=/root/rsync-home.log \
  --exclude=/lost+found /home/ /mnt/pool/@home/ ; echo "exit $?"   # expect: 0
umount /home && cryptsetup close luks-ad3fca90-eebe-4e31-96c4-46d3f1b6e4f1 \
  && mount -o subvol=@home,compress=zstd:1,noatime "/dev/disk/by-uuid/$POOL" /home \
  && findmnt /home                                                 # expect: btrfs /@home. If umount fails: STOP, check fuser.
nixos-rebuild boot --flake "$FLAKE" && grep ' /home ' /nix/var/nix/profiles/system/etc/fstab \
  && systemctl reboot                                              # expect: subvol=@home
```

### 2d. Verify (before the old home is wiped)
```sh
source /root/btrfs-migration.env
cryptsetup open --readonly /dev/disk/by-id/nvme-WDC_PC_SN730_SDBQNTY-1T00-1001_20506T459605-part1 oldhome
mkdir -p /mnt/oldhome && mount -o ro,noload /dev/mapper/oldhome /mnt/oldhome
rsync -naiHAXS --numeric-ids --delete --exclude=/lost+found /mnt/oldhome/ /home/ > /root/home-verify.txt ; echo "exit $?"
less /root/home-verify.txt                                         # expect: only files changed since 2c
umount /mnt/oldhome && cryptsetup close oldhome
```
**Podman/kind:** your existing kind and camp clusters were created on ext4, so recreate them now. kind binds `/dev/mapper` only when it creates a cluster on btrfs. Check that a node becomes Ready and that a Testcontainers suite passes.

---

## Step 3: WD in, SATA out (in tmux; online)

### 3a. Prepare WD (point of no return for the old home)
```sh
source /root/btrfs-migration.env
WD=/dev/disk/by-id/nvme-WDC_PC_SN730_SDBQNTY-1T00-1001_20506T459605 && echo "WD=$WD" >> /root/btrfs-migration.env
cryptsetup luksUUID "$WD-part1"                                    # expect: ad3fca90-eebe-4e31-96c4-46d3f1b6e4f1
cryptsetup status luks-ad3fca90-eebe-4e31-96c4-46d3f1b6e4f1; cryptsetup status oldhome   # expect: both inactive
bash /home/rasmus/nixos-config/btrfs-migration-luks-format.sh WD_LUKS="$WD-part1" && source /root/btrfs-migration.env
```
Config: add a LUKS entry for `<WD_LUKS>`. Then run `nixos-rebuild boot --flake "$FLAKE"`.

### 3b. Replace, then raid1 metadata
```sh
source /root/btrfs-migration.env
btrfs filesystem show /                                            # note SATA's devid
$INH btrfs replace start -B <sata-devid> "/dev/mapper/luks-$WD_LUKS" /   # progress: btrfs replace status /
btrfs filesystem show /                                            # expect: Samsung p2 + WD only
btrfs filesystem resize <sata-devid>:max /                         # WD keeps SATA's devid
$INH btrfs balance start -mconvert=raid1 /
btrfs filesystem df /                                              # expect: Data single, Metadata+System RAID1
```
If the machine reboots in the middle: both devices are in the config, so it boots, and the replace resumes or can be restarted. An interrupted balance can be restarted the same way.

---

## Step 4: SATA p2 → `/data`
```sh
source /root/btrfs-migration.env
btrfs filesystem show / | grep -c "luks-$SATA_LUKS"                # expect: 0
cp -a /data/temp-backup-of-kde /home/rasmus/
mkfs.btrfs -f -L data "/dev/mapper/luks-$SATA_LUKS" && udevadm settle
DATA=$(blkid -p -s UUID -o value "/dev/mapper/luks-$SATA_LUKS")
[ -n "$DATA" ] && [ "$DATA" != "$POOL" ] && echo "DATA=$DATA" >> /root/btrfs-migration.env && echo ok   # expect: ok
mkdir -p /mnt/data && mount "/dev/disk/by-uuid/$DATA" /mnt/data \
  && btrfs subvolume create /mnt/data/@data && chown rasmus:users /mnt/data/@data && umount /mnt/data
fuser -vm /data                                                    # expect: only the kernel mount line
umount /data && cryptsetup close luks-7da2e744-45ca-4d4b-a58e-edab3f92b966 \
  && mount -o subvol=@data,compress=zstd:1,noatime,user_subvol_rm_allowed,nosuid,nodev "/dev/disk/by-uuid/$DATA" /data \
  && systemd-tmpfiles --create --prefix=/data && chown rasmus:users /data/camp \
  && ls -la /data/camp                                             # expect: btrfs-cmp owned by rasmus
```
Config:
- `fileSystems."/data"`: set `device = "/dev/disk/by-uuid/<DATA>";` and `options = [ "subvol=@data" ] ++ btrfsOpts ++ [ "user_subvol_rm_allowed" "nosuid" "nodev" ];`. Keep the comment.
- Remove `luks-7da2e744-…`. Keep `<SATA_LUKS>`.

Then run `nixos-rebuild boot --flake "$FLAKE"`.

---

## Step 5: grow Samsung p2 (in tmux; online)
This edits the partition table of a disk the pool is on. Read every line before running it.
```sh
source /root/btrfs-migration.env
SDEV=$(readlink -f "$SAMSUNG")                                     # growpart needs /dev/nvmeXn1, not the by-id name
cryptsetup status luks-41434903-08ad-473f-bd3d-e8e01ef1762e; cryptsetup status luks-7da2e744-45ca-4d4b-a58e-edab3f92b966   # expect: both inactive
sgdisk --backup=/root/gpt-step5.bin "$SDEV" && cp /root/gpt-step5.bin /boot/ && cp /root/gpt-step5.bin /data/
sgdisk -p "$SDEV"                                                  # expect: p1..p4 as at the top
sgdisk -d 3 -d 4 "$SDEV" && partx -d --nr 3:4 "$SDEV" && growpart "$SDEV" 2 \
  && lsblk "$SDEV"                                                 # expect: p2 ~953G, no p3/p4
cryptsetup resize "luks-$P2_LUKS"                                  # asks for the passphrase (LUKS2)
btrfs filesystem show /                                            # note p2's devid
btrfs filesystem resize <p2-devid>:max /
```
Rollback before `cryptsetup resize`: `sgdisk --load-backup=/data/gpt-step5.bin "$SDEV" && partx -u "$SDEV"`. The start sector of p2 never changes.

---

## Step 6: wrap-up
1. In `gc.nix`, set `automatic = true` again. Then run `sudo nixos-rebuild boot --flake /home/rasmus/nixos-config#rhdh-work-desktop`.
2. **Reboot.** This proves the final layout boots, and ends rule 3. Expect:
   - one passphrase prompt
   - `/`, `/nix` and `/home` on the pool
   - `/data` and swap on SATA
   - Intune still shows the disk as encrypted
3. Lock root again (`sudo passwd -l root`), but only if step 0.6 showed `L`.
4. Clean up old generations: `sudo nix-collect-garbage --delete-older-than 1d`, then run the same `sudo nixos-rebuild boot` as in point 1.
5. Run `balooctl6 purge` and consider excluding `~/projects` from indexing. For future VM images, run `chattr +C` on the empty images directory first. autoScrub is already enabled and picks up the pool automatically.
6. Delete `/root/btrfs-migration.env`, `/root/rsync-*.log`, `/root/home-verify.txt`, and every copy of `gpt-step5.bin` (`/root`, `/boot`, `/data`).
7. Remove `boot.initrd.systemd.emergencyAccess = true;` (from 1.3), then run the same `sudo nixos-rebuild boot` again.

## Interruptions
| Step | You | Background |
|---|---|---|
| 0 | reboot + power-off | cleanup, smoke test |
| 1 | ~10–15 min + reboot | root copy ~30–60 min |
| 2 | ~5–15 min + reboot | home copy, hours |
| 3–5 | none | replace + balance ~30–60 min |
| 6 | one reboot when it suits you | |
