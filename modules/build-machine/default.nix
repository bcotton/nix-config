{config, ...}: {
  ####################################################################
  #
  #  NixOS's Configuration for Remote Building / Distributed Building
  #
  ####################################################################

  # Set local's max-jobs to 0 to force remote building (disable local building).
  nix.settings.trusted-users = ["root" "builder"];

  nix.settings.max-jobs = 0;
  nix.distributedBuilds = true;
  nix.buildMachines = let
    # pattern to use to not use the current machine as a remote builder
    currentHost = "builder-${config.networking.hostName}";
    sshUser = "builder";
    # Path to the SSH key on the local machine.
    sshKey = "/run/agenix/builder-private-key";
    systems = [
      # Native architecture.
      "x86_64-linux"

      # Emulated architecture using binfmt_misc and qemu-user.
      # "aarch64-linux"
      # "riscv64-linux"
    ];
    # All available system features are poorly documented here:
    # https://github.com/NixOS/nix/blob/e503ead/src/libstore/globals.hh#L673-L687
    supportedFeatures = [
      "benchmark"
      "big-parallel"
      "kvm"
      "nixos-test"
    ];
  in [
    # in builtins.filter (machine: machine.hostName != currentHost) [
    # Nix seems to always prioritize remote building.
    # To make use of the local machine's high-performance CPU, do not set the remote builder's maxJobs too high.
    {
      # Some of my remote builders are running NixOS
      # and have the same sshUser, sshKey, systems, etc.
      inherit sshUser sshKey systems supportedFeatures;

      # The hostName should be:
      #   1. A hostname that can be resolved by DNS.
      #   2. The IP address of the remote builder.
      #   3. A host alias defined globally in /etc/ssh/ssh_config.
      hostName = "builder-nix-01";
      # Remote builder's max-jobs.
      maxJobs = 3;
      # SpeedFactor is a signed integer,
      # but it seems that it's not used by Nix and has no effect.
      speedFactor = 1;
    }
    {
      inherit sshUser sshKey systems supportedFeatures;
      hostName = "builder-nix-02";
      maxJobs = 2;
      speedFactor = 1;
    }
    {
      inherit sshUser sshKey systems supportedFeatures;
      hostName = "builder-nix-03";
      maxJobs = 2;
      speedFactor = 1;
    }
  ];
  # Optional: Useful when the builder has a faster internet connection than yours.
  # nix.extraOptions = ''
  # 	builders-use-substitutes = true
  # '';

  # Define the host aliases for remote builders.
  # This configuration will be written to /etc/ssh/ssh_config.
  programs.ssh.extraConfig = ''
    Host builder-nix-01
      HostName 192.168.5.210
      Port 22
      IdentitiesOnly yes
      IdentityFile /run/agenix/builder-private-key
      # The weakly privileged user on the remote builder – if not set, 'root' is used – which will hopefully fail
      User builder

    Host builder-nix-02
      HostName 192.168.5.212
      Port 22
      IdentitiesOnly yes
      IdentityFile /run/agenix/builder-private-key
      # The weakly privileged user on the remote builder – if not set, 'root' is used – which will hopefully fail
      User builder

    Host builder-nix-03
      HostName 192.168.5.214
      Port 22
      IdentitiesOnly yes
      IdentityFile /run/agenix/builder-private-key
      # The weakly privileged user on the remote builder – if not set, 'root' is used – which will hopefully fail
      User builder
  '';

  # Define the host keys for remote builders so that Nix can verify all the remote builders.
  # This configuration will be written to /etc/ssh/ssh_known_hosts.
  programs.ssh.knownHosts = {
    "nix-01.lan" = {
      hostNames = ["nix-01.lan" "192.168.5.210"];
      publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJDEJMkba6F8w5b1nDZ3meKEb7PNcWbErBtofbejrIh+ root@nix-01";
    };
    "nix-02.lan" = {
      hostNames = ["nix-02.lan" "192.168.5.212"];
      publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFP84qqvaOkowcYY3B1b96AJ3TPBo0EOlIJuqYQF/AfM root@nix-02";
    };
    "nix-03.lan" = {
      hostNames = ["nix-03.lan" "192.168.5.214"];
      publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEQtcczbSCjUK0NH1M6fTIG21Ta5XcvygsFimfNDMqXz root@nix-03";
    };
  };
}
