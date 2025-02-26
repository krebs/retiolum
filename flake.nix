{
  description = "Nix flake for retiolum VPN";

  outputs = { self }: {
    nixosModules.retiolum = import ./modules/retiolum;
  };
}
