# Post-reboot: KWallet consolidation checks

Context: `pam_kwallet5` can only auto-unlock a wallet named `kdewallet`. It always derives the key from `~/.local/share/kwalletd/kdewallet.salt`, then opens the *default* wallet with it. The default was `login`, so it never auto-unlocked. `login` has been merged into `kdewallet` (XML export → import, Replace All).

Backup from before the merge: `/data/temp-backup-of-kde/`

## Before rebooting

- [ ] System Settings → KDE Wallet: default wallet = `kdewallet` ("different wallet for local passwords" unchecked)
- [ ] `grep 'Default Wallet' ~/.config/kwalletrc` shows `kdewallet`, or no line at all

## After rebooting

1. [ ] Log in and start Chrome, JetBrains, etc. You should get **no wallet password prompt**.

2. [ ] KWallet was unlocked by PAM:
   ```
   busctl --user call org.kde.secretservicecompat /ksecretd org.kde.KWallet isOpen s kdewallet   # → b true
   journalctl -b | rg -i 'opened by PAM'                                                          # → "Wallet opened by PAM"
   ```
   If it says "failed to get opened by PAM": `kdewallet`'s password ≠ login password, or the wallet is not Blowfish. Fix it with KWalletManager → `kdewallet` → Change Password (login password, Blowfish).

3. [ ] GNOME keyring unlocked by itself (without typing anything):
   ```
   busctl --user get-property org.freedesktop.secrets /org/freedesktop/secrets/collection/login org.freedesktop.Secret.Collection Locked   # → b false
   ```
   If `b true`, it's a separate issue. Grab `journalctl -b -t gnome-keyring-daemon` before the journal rotates.

4. [ ] Apps still have their secrets: Chrome saved passwords and sign-ins, JetBrains/Toolbox logged in, Remmina connection passwords.

## Clean up (only if all of the above passed)

5. [ ] Check that nothing was written to `login` after the merge (25 Nov, 10:14):
   ```
   ls -la --time-style=full-iso ~/.local/share/kwalletd/login.kwl
   ```
   If it's newer than the merge: KWalletManager → open `login` → Export as XML to `/run/user/1000/login.xml`. Then open `kdewallet` → Import XML (Replace All) and run `rm /run/user/1000/login.xml`.

6. [ ] KWalletManager → delete the `login` wallet. Only `kdewallet` should remain.

7. [ ] Once happy for a while, delete `/data/temp-backup-of-kde/`. It contains your wallets.

## Rollback

```
cp -a /data/temp-backup-of-kde/kwalletd/. ~/.local/share/kwalletd/
cp /data/temp-backup-of-kde/kwalletrc ~/.config/kwalletrc
systemctl reboot
```

## Optional repo cleanup (`software/intune.nix`)

- Remove the no-op lines `security.pam.services.sddm.kwallet.enable = true;` and `security.pam.services.sddm.enableGnomeKeyring = true;`. The sddm PAM stack only includes `login`, which already has both modules.
- Add a comment that the default KWallet must be named `kdewallet` for PAM unlock to work.
