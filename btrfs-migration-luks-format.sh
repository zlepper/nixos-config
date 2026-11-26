#!/usr/bin/env bash
# Formats partitions as LUKS2 with the same passphrase as every existing LUKS container.
# The systemd initrd caches the first passphrase typed at boot (crypttab password-cache,
# default on) and tries it on every container, so identical passphrases mean one prompt.
#
# Usage (as root, in bash):
#   bash btrfs-migration-luks-format.sh NAME_LUKS=/dev/disk/by-id/...-partN [NAME_LUKS=...]...
#
# 1. Checks every target (partition, not mounted/open/swap) and every reference container
#    (all other crypto_LUKS partitions; none may have a LUKS2 token, which could unlock it
#    without the passphrase).
# 2. Asks for confirmation and the passphrase, which must unlock every reference.
# 3. Formats all targets and verifies the passphrase on each.
# 4. Opens each as luks-<uuid> with the options NixOS uses (allowDiscards, bypassWorkqueues),
#    appends NAME_LUKS=<uuid> to /root/btrfs-migration.env and prints the NixOS config lines.
# If opening fails, mappings opened by this run are closed again.
#
# The passphrase goes to cryptsetup on stdin, newline-terminated, which cryptsetup handles
# exactly like typed input ("From stdin: ... up to the first newline"). It is never echoed,
# written to disk, exported or passed as an argument.
set +x
set -euo pipefail

ENV_FILE=/root/btrfs-migration.env
# No --sector-size: cryptsetup picks it from the device (512 here, as on the existing containers).
# A forced 4096 fails on partitions whose size isn't a multiple of 4 KiB.
FORMAT_OPTS=(--type luks2 --batch-mode)
OPEN_OPTS=(--allow-discards --perf-no_read_workqueue --perf-no_write_workqueue)

die() { echo "ERROR: $*" >&2; exit 1; }

[[ $EUID -eq 0 ]] || die "run as root"
(( $# >= 1 )) || die "usage: $0 NAME_LUKS=PARTITION [NAME_LUKS=PARTITION]..."

names=() parts=() devs=()
for arg in "$@"; do
  [[ $arg == *=* ]] || die "'$arg' is not NAME_LUKS=PARTITION"
  name=${arg%%=*} part=${arg#*=}
  [[ $name =~ ^[A-Z][A-Z0-9_]*_LUKS$ ]] || die "'$name' must be an upper-case name ending in _LUKS"
  dev=$(readlink -f -- "$part")
  [[ -b $dev ]] || die "$part is not a block device"
  type=$(lsblk -dno TYPE "$dev") || die "lsblk failed on $part"
  [[ $type == part ]] || die "$part is not a partition"
  tree=$(lsblk -no NAME "$dev") || die "lsblk failed on $part"
  (( $(wc -l <<<"$tree") == 1 )) || die "$part is in use (it has an open mapping or holder)"
  ! findmnt -rno TARGET -S "$dev" >/dev/null || die "$part is mounted"
  ! grep -q "^$dev " /proc/swaps || die "$part is active swap"
  for d in "${devs[@]}"; do [[ $d != "$dev" ]] || die "$part is given twice"; done
  names+=("$name") parts+=("$part") devs+=("$dev")
done

listing=$(lsblk -rpno PATH,FSTYPE) || die "lsblk failed"
refs=()
while read -r path fstype; do
  [[ $fstype == crypto_LUKS ]] || continue
  for d in "${devs[@]}"; do [[ $d != "$path" ]] || continue 2; done
  refs+=("$path")
done <<<"$listing"
(( ${#refs[@]} >= 1 )) || die "no other LUKS containers found to compare the passphrase against"
for r in "${refs[@]}"; do
  dump=$(cryptsetup luksDump "$r") || die "cannot read the LUKS header of $r"
  tokens=$(sed -n '/^Tokens:/,/^Digests:/p' <<<"$dump" | grep -cE '^ +[0-9]+: ' || true)
  (( tokens == 0 )) || die "$r has $tokens LUKS2 token(s); it could unlock without the passphrase, so it can't be used as a reference"
done

echo "Partitions to WIPE and format:"
for i in "${!devs[@]}"; do
  printf '  %s = %s\n' "${names[$i]}" "${parts[$i]}"
  lsblk -o PATH,SIZE,FSTYPE,LABEL,PARTLABEL "${devs[$i]}" | sed 's/^/      /'
done
echo "The passphrase must unlock these existing containers first:"
printf '  %s\n' "${refs[@]}"
echo
read -rp "All data on the partitions above will be destroyed. Type WIPE to continue: " answer \
  || die "no input, nothing changed"
[[ $answer == WIPE ]] || die "aborted, nothing changed"

IFS= read -rsp "Passphrase (the one you type at boot): " pw || { echo; die "no input, nothing changed"; }
echo
[[ -n $pw ]] || die "empty passphrase"
for r in "${refs[@]}"; do
  if ! out=$(printf '%s\n' "$pw" | cryptsetup open --test-passphrase -v "$r" 2>&1); then
    die "$r did not unlock (cryptsetup: ${out//$'\n'/ }); nothing changed"
  fi
  echo "  $r: $(grep -o 'Key slot [0-9]* unlocked' <<<"$out" || echo unlocked)"
done

# Phase 1: format and verify every target before opening anything.
for i in "${!devs[@]}"; do
  dev=${devs[$i]}
  echo "== formatting ${parts[$i]}"
  wipefs -a "$dev" || die "wipefs failed on $dev"
  printf '%s\n' "$pw" | cryptsetup luksFormat "${FORMAT_OPTS[@]}" "$dev" \
    || die "luksFormat failed on $dev; nothing was opened or recorded, re-run the script"
  printf '%s\n' "$pw" | cryptsetup open --test-passphrase "$dev" \
    || die "the new container on $dev does not accept the passphrase"
done

# Phase 2: open them and record the UUIDs. On failure, close what this run opened.
opened=()
cleanup() {
  for m in "${opened[@]}"; do cryptsetup close "$m" && echo "  closed $m again" >&2; done
}
trap 'echo "ERROR while opening; the containers are formatted but not recorded." >&2; cleanup' ERR
for i in "${!devs[@]}"; do
  dev=${devs[$i]}
  uuid=$(cryptsetup luksUUID "$dev")
  printf '%s\n' "$pw" | cryptsetup open "${OPEN_OPTS[@]}" "$dev" "luks-$uuid"
  opened+=("luks-$uuid")
  [[ -b /dev/mapper/luks-$uuid ]] || false
done
trap - ERR
unset pw

for i in "${!devs[@]}"; do
  echo "${names[$i]}=$(cryptsetup luksUUID "${devs[$i]}")" >> "$ENV_FILE"
done
echo "Opened and recorded in $ENV_FILE:"
for i in "${!devs[@]}"; do
  uuid=$(cryptsetup luksUUID "${devs[$i]}")
  printf '  %s=%s  (/dev/mapper/luks-%s)\n' "${names[$i]}" "$uuid" "$uuid"
done
echo
echo "Config lines for hardware/work-desktop.nix:"
for i in "${!devs[@]}"; do
  uuid=$(cryptsetup luksUUID "${devs[$i]}")
  printf '  boot.initrd.luks.devices."luks-%s" = luks "%s";   # %s\n' "$uuid" "$uuid" "${names[$i]}"
done
