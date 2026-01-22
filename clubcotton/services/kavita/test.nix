# nix build '.#checks.x86_64-linux.kavita'
# nix run '.#checks.x86_64-linux.kavita.driverInteractive'
{nixpkgs}: {
  name = "kavita";
  interactive.nodes = let
    testLib = import ../../../tests/libtest.nix {};
    lib = nixpkgs.lib;
  in {
    machine = {...}:
      lib.recursiveUpdate
      (testLib.mkSshConfig 2223)
      (testLib.portForward 8085 8085);
  };

  nodes.machine = {
    config,
    pkgs,
    ...
  }: {
    imports = [
      ./default.nix
    ];

    services.clubcotton.kavita = {
      enable = true;
      port = 8085;
      tokenKeyFile = "/var/lib/kavita/token.key";
    };

    # Create test directories and files
    systemd.tmpfiles.rules = [
      "d /var/lib/kavita 0755 kavita kavita"
      "f /var/lib/kavita/token.key 0600 kavita kavita - 8MRerWknMnLmsSnknZhXYZxOVUqwRESNae0me0eEx6mBjRzAaiW5+Q0Q3cTRWkeprCAk4HRAvBeMIc+dJFm7uw=="
      "d /var/lib/kavita/manga 0755 kavita kavita"
      "d /var/lib/kavita/comics 0755 kavita kavita"
      "d /var/lib/kavita/books 0755 kavita kavita"
    ];
  };

  testScript = ''
    start_all()

    # Wait for kavita service to start
    machine.wait_for_unit("kavita.service")
    machine.wait_for_open_port(8085)
    # Test basic HTTP connectivity
    machine.succeed(
      "curl -f http://localhost:8085/api/health"
    )

    # Verify service is running as kavita user
    machine.succeed(
      "ps aux | grep kavita | grep -v grep"
    )

    # Check data directories exist and have correct permissions
    machine.succeed(
      "test -d /var/lib/kavita/manga",
      "test -d /var/lib/kavita/comics",
      "test -d /var/lib/kavita/books",
      "stat -c '%U:%G' /var/lib/kavita/manga | grep -q 'kavita:kavita'",
      "stat -c '%U:%G' /var/lib/kavita/comics | grep -q 'kavita:kavita'",
      "stat -c '%U:%G' /var/lib/kavita/books | grep -q 'kavita:kavita'"
    )
  '';
}
