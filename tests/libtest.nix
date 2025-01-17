{...}: {
  mkSshConfig = port: {
    # SSH access configuration
    services.openssh = {
      enable = true;
      settings = {
        PermitRootLogin = "yes";
        PermitEmptyPasswords = "yes";
      };
    };
    security.pam.services.sshd.allowNullPassword = true;
    virtualisation.forwardPorts = [
      {
        from = "host";
        host.port = port;
        guest.port = 22;
      }
    ];
  };
  portForward = hostPort: targetPort: {
    virtualisation.forwardPorts = [
      {
        from = "host";
        host.port = hostPort;
        guest.port = targetPort;
      }
    ];
    networking.firewall.allowedTCPPorts = [targetPort];
  };
}
