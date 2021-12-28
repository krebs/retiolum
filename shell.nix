{ pkgs ? import <nixpkgs> {}, lib ? import <nixpkgs/lib> }:
let
  stockholmMirrors = {
    tv = "https://cgit.krebsco.de/stockholm"; # ni.r
    lassulus = "https://cgit.lassul.us/stockholm"; # prism.r
    mic92 = "https://git.thalheim.io/Mic92/stockholm";
    makefu = "https://cgit.euer.krebsco.de/stockholm"; # gum.r
    kmein = "https://github.com/kmein/stockholm";
  };
in
pkgs.mkShell {
  buildInputs = [
    (pkgs.writers.writeDashBin "generate-hosts" ''
      set -xefu

      ${pkgs.git}/bin/git config --global user.name krebs
      ${pkgs.git}/bin/git config --global user.email spam@krebsco.de

      stockholm_directory=$(${pkgs.coreutils}/bin/mktemp -d)
      trap clean EXIT
      clean() {
        cd ${toString ./.}
        rm -rf "$stockholm_directory"
      }
      cd "$stockholm_directory"

      random_upstream=$(
        ${pkgs.coreutils}/bin/printf '%s\n' ${toString (builtins.attrValues stockholmMirrors)} \
        | ${pkgs.coreutils}/bin/shuf -n 1
      )

      ${pkgs.git}/bin/git clone "$random_upstream" "$stockholm_directory"

      ${lib.concatStringsSep "\n" (lib.mapAttrsToList (user: url: ''
        ${pkgs.git}/bin/git remote add ${user} ${url}
        ${pkgs.git}/bin/git fetch ${user} master
      '') stockholmMirrors)}

      ${pkgs.git}/bin/git merge -m lol ${toString (lib.mapAttrsToList (user: _: "${user}/master") stockholmMirrors)}

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
          wiregrillHosts = filterAttrs (_: h: builtins.isAttrs h && hasAttr "wiregrill" h.nets) config.krebs.hosts;
        in
        pkgs.writeText "hosts" (builtins.toJSON (mapAttrs (_: host:
          let
            wiregrill = host.nets.wiregrill;
          in {
            allowedIPs =
              if isRouter then
                optional (!isNull wiregrill.ip4) wiregrill.ip4.addr ++
                optional (!isNull wiregrill.ip6) wiregrill.ip6.addr
              else
                wiregrill.wireguard.subnets;
            publicKey = replaceStrings ["\n"] [""] wiregrill.wireguard.pubkey;
          } // optionalAttrs (!isNull wiregrill.via) {
            endpoint = "''${wiregrill.via.ip4.addr}:''${toString wiregrill.wireguard.port}";
            persistentKeepalive = 61;
          }) wiregrillHosts
        ))
      ''} wiregrill.nix

      export NIX_PATH=stockholm=.:nixos-config=dummy.nix:secrets=krebs/0tests/data/secrets:$NIX_PATH

      hosts_archive=$(${pkgs.nix}/bin/nix-build --no-out-link '<nixpkgs/nixos>' -A config.krebs.tinc.retiolum.hostsArchive)
      ${pkgs.gnutar}/bin/tar -C ${toString ./.} -xf "$hosts_archive"

      etc_hosts=$(${pkgs.nix}/bin/nix-build --no-out-link '<nixpkgs/nixos>' -A pkgs.krebs-hosts)
      ${pkgs.coreutils}/bin/cp "$etc_hosts" ${toString ./.}/etc.hosts

      wiregrill_json=$(${pkgs.nix}/bin/nix-build --no-out-link wiregrill.nix)
      ${pkgs.jq}/bin/jq < "$wiregrill_json" > ${toString ./.}/wiregrill.json
    '')
  ];
}
