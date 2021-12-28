{ pkgs ? import <nixpkgs> {} }:
let
  stockholmMirrors = [
    "https://cgit.krebsco.de/stockholm" # tv@ni.r
    "https://cgit.lassul.us/stockholm" # lassulus@prism.r
    "https://git.thalheim.io/Mic92/stockholm" # mic92
    "https://cgit.euer.krebsco.de/stockholm" # makefu@gum.r
  ];
in
pkgs.mkShell {
  buildInputs = [
    (pkgs.writers.writeDashBin "generate-hosts" ''
      set -efu

      stockholm_mirrors() {
        for mirror in ${toString stockholmMirrors}; do
          directory=$(${pkgs.coreutils}/bin/mktemp -d)
          ${pkgs.git}/bin/git clone --depth 1 "$mirror" "$directory" 2>/dev/null
          (
            cd "$directory"
            ${pkgs.coreutils}/bin/printf "%d %s %s\n" "$(${pkgs.git}/bin/git log --pretty=format:%ct)" "$mirror" "$directory"
          )
        done
      }

      # most recent mirror
      stockholm=$(stockholm_mirrors | ${pkgs.coreutils}/bin/sort -r -n | ${pkgs.coreutils}/bin/head -n 1 | ${pkgs.coreutils}/bin/cut -d' ' -f 3)

      cd "$stockholm"

      ${pkgs.git}/bin/git submodule update --init --recursive

      cp ${pkgs.writeText "dummy.nix" ''
        { config, lib, pkgs, ... }: {
          imports = [ ./krebs ];
          krebs = {
            enable = true;
            tinc.retiolum.enable = true;
            build.host = config.krebs.hosts.prism;
            build.user = config.krebs.users.krebs;
          };
        }
      ''} dummy.nix

      ${pkgs.coreutils}/bin/cp ${pkgs.writeText "wiregrill.nix" ''
        with import <nixpkgs/nixos> {};
        with import <stockholm/lib>;
        let
          self = config.krebs.build.host.nets.wiregrill;
          isRouter = !isNull self.via;
          wiregrillHosts = filterAttrs (_: h: (builtins.isAttrs h) && (hasAttr "wiregrill" h.nets)) config.krebs.hosts;
        in
        pkgs.writeText "hosts" (builtins.toJSON
          (mapAttrs (_: host: let
              wiregrill = host.nets.wiregrill;
            in {
            allowedIPs = if isRouter then
                           (optional (!isNull wiregrill.ip4) wiregrill.ip4.addr) ++
                           (optional (!isNull wiregrill.ip6) wiregrill.ip6.addr)
                         else
                           wiregrill.wireguard.subnets;
            publicKey = replaceStrings ["\n"] [""] wiregrill.wireguard.pubkey;
          } // optionalAttrs (!isNull wiregrill.via) {
            endpoint =  "''${wiregrill.via.ip4.addr}:''${toString wiregrill.wireguard.port}";
            persistentKeepalive = 61;
          }) wiregrillHosts))
      ''} wiregrill.nix

      ${pkgs.nix}/bin/nix build \
        -I secrets=./krebs/0tests/data/secrets \
        -I nixos-config=./dummy.nix \
        -I stockholm=./. \
        -f '<nixpkgs/nixos>' \
        config.krebs.tinc.retiolum.hostsArchive pkgs.krebs-hosts

      ${pkgs.gnutar}/bin/tar -C ${toString ./.} -xf result
      ${pkgs.coreutils}/bin/cp result-1 ${toString ./.}/etc.hosts

      ${pkgs.nix}/bin/nix-build ./wiregrill.nix \
        -I secrets=./krebs/0tests/data/secrets \
        -I nixos-config=./dummy.nix \
        -I stockholm=./.

      ${pkgs.jq}/bin/jq < result > ${toString ./.}/wiregrill.json
    '')
  ];
}
