{ pkgs, ... }:
let
  # --- Chrome <-> Microsoft Identity Broker SSO bridge (linux-entra-sso) ---
  # Chrome on Linux cannot satisfy device-based Conditional Access on its own:
  # the official "Microsoft Single Sign On" extension only talks to the
  # Windows/macOS-only `com.microsoft.browsercore` native host. Edge speaks to
  # the broker directly over D-Bus, but Chrome needs a bridge. siemens'
  # linux-entra-sso provides a native-messaging host that calls the broker's
  # `acquirePrtSsoCookie` (verified working against broker 3.0.1) plus a
  # companion extension. Not packaged in nixpkgs, so we build it from source.
  entraSsoExtId = "jlnfnnolkbjieggibinobhkjdfbpcohn"; # signed Chrome Web Store id

  entraSsoSrc = pkgs.fetchFromGitHub {
    owner = "siemens";
    repo = "linux-entra-sso";
    rev = "v1.9.1";
    hash = "sha256-3OF9Rk3oQJjJgDyV8/Uhfo0BKYYHKSD0vy70S5lmICs=";
  };

  entraSsoPython = pkgs.python3.withPackages (ps: with ps; [ pygobject3 pydbus ]);

  # Wrap the stdio host so `gi`/pydbus find the GLib + Gio typelibs at runtime.
  # Also usable as a CLI for debugging: `linux-entra-sso -i getAccounts`.
  entraSsoHost = pkgs.runCommand "linux-entra-sso-host" {
    nativeBuildInputs = [ pkgs.makeWrapper ];
  } ''
    install -Dm644 ${entraSsoSrc}/linux-entra-sso.py \
      $out/lib/linux-entra-sso/linux-entra-sso.py
    makeWrapper ${entraSsoPython}/bin/python3 $out/bin/linux-entra-sso \
      --add-flags "$out/lib/linux-entra-sso/linux-entra-sso.py" \
      --prefix GI_TYPELIB_PATH : "${pkgs.lib.makeSearchPath "lib/girepository-1.0" [ pkgs.glib ]}"
  '';
in
{

  environment.systemPackages = with pkgs;
    [
      microsoft-edge
      seahorse
      entraSsoHost
    ];

  security.pam.services.sddm.kwallet.enable = true;
  services.gnome.gnome-keyring.enable = true;
  security.pam.services.sddm.enableGnomeKeyring = true;
  security.pam.services.passwd.enableGnomeKeyring = true;

  services.envfs.enable = true;

  environment.etc."xdg/kwalletrc".text = ''
    [org.freedesktop.secrets]
    apiEnabled=false
  '';

  nixpkgs.overlays = [
  (final: prev: {
    microsoft-edge = prev.microsoft-edge.overrideAttrs (old: {
      postFixup = (old.postFixup or "") + ''
        # Inject missing dynamic libraries and the NixOS SSL trust store into the Edge wrapper
        wrapProgram $out/bin/microsoft-edge \
          --prefix LD_LIBRARY_PATH : "${final.lib.makeLibraryPath (with final; [
            libsecret
            glib
            libxml2
            libuuid
            stdenv.cc.cc.lib
          ])}" \
          --set SSL_CERT_FILE "${final.cacert}/etc/ssl/certs/ca-bundle.crt"
      '';
    });

    microsoft-identity-broker = prev.microsoft-identity-broker.overrideAttrs (old: {
      nativeBuildInputs = (old.nativeBuildInputs or []) ++ [ final.makeWrapper ];
      postFixup = (old.postFixup or "") + ''
        for bin in microsoft-identity-broker microsoft-identity-device-broker; do
          wrapProgram $out/bin/$bin \
            --prefix LD_LIBRARY_PATH : "${final.lib.makeLibraryPath (with final; [
              libsecret
              glib
              libxml2
              libuuid
              stdenv.cc.cc.lib
            ])}" \
            --prefix GIO_EXTRA_MODULES : "${final.glib-networking}/lib/gio/modules" \
            --set SSL_CERT_FILE "${final.cacert}/etc/ssl/certs/ca-bundle.crt" \
            --set CURL_CA_BUNDLE "${final.cacert}/etc/ssl/certs/ca-bundle.crt" \
            --set GDK_BACKEND x11 \
            --set WEBKIT_DISABLE_DMABUF_RENDERER "1" \
            --set MIP_CACHE_DIR "$HOME/.local/share/microsoft-identity-broker" \
            --run 'export STATE_DIRECTORY="''${STATE_DIRECTORY:-$HOME/.local/state/microsoft-identity-broker}"'
        done
      '';
    });

    intune-portal = prev.intune-portal.overrideAttrs (old: {
      nativeBuildInputs = (old.nativeBuildInputs or []) ++ [ final.makeWrapper ];
      postFixup = (old.postFixup or "") + ''
        for bin in intune-portal intune-daemon intune-agent; do
          if [ -f "$out/bin/$bin" ]; then
            wrapProgram "$out/bin/$bin" \
              --prefix PATH : "${final.lib.makeBinPath ([ final.dmidecode final.util-linux final.cryptsetup final.curl final.gawk final.gnugrep final.gnused final.systemd final.iproute2 final.nettools final.coreutils final.bash final.dash final.lsb-release ])}" \
              --prefix LD_LIBRARY_PATH : "${final.lib.makeLibraryPath (with final; [
                libsecret
                glib
                libxml2
                libuuid
                stdenv.cc.cc.lib
              ])}" \
              --prefix GIO_EXTRA_MODULES : "${final.glib-networking}/lib/gio/modules" \
              --set SSL_CERT_FILE "${final.cacert}/etc/ssl/certs/ca-bundle.crt" \
              --set CURL_CA_BUNDLE "${final.cacert}/etc/ssl/certs/ca-bundle.crt" \
              --set WEBKIT_DISABLE_DMABUF_RENDERER "1" \
              --run 'export STATE_DIRECTORY="''${STATE_DIRECTORY:-$HOME/.local/state/intune}"'
          fi
        done
      '';
    });
  })
];

  # Hack Intune to work
  services.intune.enable = true;
  xdg.portal.enable = true;

  # 4. Mandatory OS Spoofing: Convince Intune's inventory check that this machine runs Ubuntu 24.04 LTS
  environment.etc."os-release".text = pkgs.lib.mkForce ''
    NAME="Ubuntu"
    VERSION="24.04 LTS (Noble Numbat)"
    ID=ubuntu
    ID_LIKE=debian
    PRETTY_NAME="Ubuntu 24.04 LTS"
    VERSION_ID="24.04"
    HOME_URL="https://www.ubuntu.com/"
    SUPPORT_URL="https://help.ubuntu.com/"
    BUG_REPORT_URL="https://bugs.launchpad.net/ubuntu/"
    PRIVACY_POLICY_URL="https://www.ubuntu.com/legal/terms-and-policies/privacy-policy"
    UBUNTU_CODENAME=noble
  '';

  # Native-messaging host the linux-entra-sso Chrome extension connects to.
  # It bridges the extension to the broker's `acquirePrtSsoCookie` D-Bus method.
  environment.etc."opt/chrome/native-messaging-hosts/linux_entra_sso.json".text =
    builtins.toJSON {
      name = "linux_entra_sso";
      description = "Entra ID SSO via Microsoft Identity Broker";
      path = "${entraSsoHost}/bin/linux-entra-sso";
      type = "stdio";
      allowed_origins = [ "chrome-extension://${entraSsoExtId}/" ];
    };

  # Force-install the companion extension so the bridge is reproducible. The
  # official "Microsoft Single Sign On" extension is a no-op on Linux and can
  # be removed from Chrome.
  environment.etc."opt/chrome/policies/managed/linux-entra-sso.json".text =
    builtins.toJSON {
      ExtensionInstallForcelist = [
        "${entraSsoExtId};https://clients2.google.com/service/update2/crx"
      ];
    };

}
