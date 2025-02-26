{
  description = "Nix flake for retiolum VPN";

  outputs = { self }: {
    nixosModules.retiolum = import ./modules/retiolum;
    nixosModules.ca = import ./modules/ca;
  };
}
