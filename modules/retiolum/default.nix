{ config, pkgs, lib, ... }:

with lib;

let
  netname = "retiolum";
  cfg = config.networking.retiolum;
  hosts = ../../hosts;
  genipv6 = import ./genipv6.nix { inherit lib; };
in {
  options = {
    networking.retiolum.ipv4 = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = ''
        own ipv4 address
      '';
    };
    networking.retiolum.ipv6 = mkOption {
      type = types.str;
      default = (genipv6 "retiolum" "external"  {
        hostName = cfg.nodename;
      }).address;
      description = ''
        own ipv6 address
      '';
    };
    networking.retiolum.nodename = mkOption {
      type = types.str;
      default = config.networking.hostName;
      description = ''
        tinc network name
      '';
    };
    networking.retiolum.port = mkOption {
      type = types.int;
      default = 655;
      description = ''
        port tinc is listen
      '';
    };
  };

  config = {
    services.tinc.networks.${netname} = {
      name = cfg.nodename;
      # allow resolving dns
      chroot = false;
      extraConfig = ''
        Port = ${toString cfg.port}
        LocalDiscovery = yes

        ConnectTo = eva
        ConnectTo = eve
        ConnectTo = ni
        ConnectTo = prism
        AutoConnect = yes
      '';
    };

    networking.extraHosts = builtins.readFile ../../etc.hosts;

    environment.systemPackages = [
      config.services.tinc.networks.${netname}.package
    ];

    systemd.services."tinc.${netname}-host-keys" = let
      install-keys = pkgs.writeShellScript "install-keys" ''
        rm -rf /etc/tinc/${netname}/hosts.tmp
        mkdir /etc/tinc/${netname}/hosts.tmp
        cp -R ${hosts}/* /etc/tinc/${netname}/hosts.tmp
        chown -R tinc-${netname} /etc/tinc/${netname}/hosts.tmp
        chmod -R u+w /etc/tinc/${netname}/hosts.tmp

        rm -rf /etc/tinc/${netname}/hosts
        mv /etc/tinc/${netname}/hosts{.tmp,}
      '';
    in {
      description = "Install tinc.${netname} host keys";
      wantedBy = [ "multi-user.target" ];
      before = [ "tinc.${netname}.service" ];
      # we reload here to be reloaded before tinc reloads
      reloadIfChanged = true;
      serviceConfig = {
        Type = "oneshot";
        ExecStart = install-keys;
        ExecReload = install-keys;
        RemainAfterExit = true;
      };
    };

    systemd.services."tinc.${netname}" = {
      restartTriggers = [ hosts ];
      # upstream defines this, but since we also set reloadIfChanged, we get a warning.
      reloadTriggers = lib.mkForce [ ];
      # Some hosts require VPN for nixos-rebuild, so we don't want to restart it on update
      reloadIfChanged = true;
    };

    networking.firewall.allowedTCPPorts = [ cfg.port ];
    networking.firewall.allowedUDPPorts = [ cfg.port ];

    warnings = lib.optional (cfg.ipv6 == null) ''
      `networking.retiolum.ipv6` is not set
    '';

    systemd.network.enable = true;
    networking.useNetworkd = true;
    systemd.network.networks."${netname}".extraConfig = ''
      [Match]
      Name = tinc.${netname}

      [Link]
      # tested with `ping -6 turingmachine.r -s 1378`, not sure how low it must be
      MTUBytes=1377

      [Network]
      ${optionalString (cfg.ipv4 != null) "Address=${cfg.ipv4}/12"}
      ${optionalString (cfg.ipv6 != null) "Address=${cfg.ipv6}/16"}
      RequiredForOnline = no
      LinkLocalAddressing = no
    '';
  };
}
