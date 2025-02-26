{ config, ... }: {
  #hack for modprobe inside containers
  systemd.services."wireguard-wiregrill".path = mkIf config.boot.isContainer (mkBefore [
    (pkgs.writeDashBin "modprobe" ":")
  ]);

  boot.kernel.sysctl = mkIf isRouter {
    "net.ipv6.conf.all.forwarding" = 1;
  };
  krebs.iptables.tables.filter.INPUT.rules = [
     { predicate = "-p udp --dport ${toString self.wireguard.port}"; target = "ACCEPT"; }
  ];
  krebs.iptables.tables.filter.FORWARD.rules = mkIf isRouter [
    { precedence = 1000; predicate = "-i wiregrill -o wiregrill"; target = "ACCEPT"; }
  ];

  networking.wireguard.interfaces.wiregrill = {
    ips =
      (optional (!isNull self.ip4) self.ip4.addr) ++
      (optional (!isNull self.ip6) self.ip6.addr);
    listenPort = 51820;
    privateKeyFile = (toString <secrets>) + "/wiregrill.key";
    allowedIPsAsRoutes = true;
    peers = mapAttrsToList
      (_: host: {
        allowedIPs = if isRouter then
          (optional (!isNull host.nets.wiregrill.ip4) host.nets.wiregrill.ip4.addr) ++
          (optional (!isNull host.nets.wiregrill.ip6) host.nets.wiregrill.ip6.addr)
        else
          host.nets.wiregrill.wireguard.subnets
        ;
        endpoint = mkIf (!isNull host.nets.wiregrill.via) (host.nets.wiregrill.via.ip4.addr + ":${toString host.nets.wiregrill.wireguard.port}");
        persistentKeepalive = mkIf (!isNull host.nets.wiregrill.via) 61;
        publicKey = (replaceStrings ["\n"] [""] host.nets.wiregrill.wireguard.pubkey);
      })
      (filterAttrs (_: h: hasAttr "wiregrill" h.nets) config.krebs.hosts);
  };
}
