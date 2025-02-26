{ config, lib, pkgs, ... }: let
  cfg = config.retiolum.ca;
in {
  options.retiolum.ca = {
    rootCA = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
      default = builtins.readFile ./root-ca.crt;
      defaultText = "root-ca.crt";
    };
    intermediateCA = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
      default = builtins.readFile ./intermediate-ca.crt;
      defaultText = "intermediate-ca.crt";
    };
    acmeURL = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
      default = "https://ca.r/acme/acme/directory";
      description = ''
        security.acme.certs.$name.server = config.retiolum.ca.acmeURL;
      '';
    };
    trustRoot = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        whether to trust the krebs root CA.
        This implies that krebs can forge a certficate for every domain
      '';
    };
    trustIntermediate = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        whether to trust the krebs ACME CA.
        this only trusts the intermediate cert for .w and .r domains
      '';
    };
  };
  config = lib.mkMerge [
    (lib.mkIf cfg.trustRoot {
      security.pki.certificates = [ cfg.rootCA ];
    })
    (lib.mkIf cfg.trustIntermediate {
      security.pki.certificates = [ cfg.intermediateCA ];
    })
  ];
}
