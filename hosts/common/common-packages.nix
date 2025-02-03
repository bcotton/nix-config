{
  config,
  pkgs,
  unstablePkgs,
  inputs,
  system,
  ...
}: {
  config = {
    environment.systemPackages = with pkgs; [
      inputs.agenix.packages."${system}".default
      atuin
      ## unstable
      yt-dlp
      get_iplayer
      monaspace

      diffnav

      ## stable
      #  asciinema
      bat
      bat-extras.batman
      bat-extras.batgrep
      bat-extras.batdiff
      bat-extras.batwatch
      bat-extras.prettybat
      btop

      # K8s development tools
      ctlptl
      tilt
      kind

      coreutils
      coreutils-prefixed
      cue
      curl
      diffr # Modern Unix `diff`
      difftastic # Modern Unix `diff`
      dig
      dua # Modern Unix `du`
      duf # Modern Unix `df`
      du-dust # Modern Unix `du`
      # direnv # programs.direnv
      #docker
      drill
      du-dust
      dua
      duf
      entr # Modern Unix `watch`
      eza
      #  ffmpeg
      #  fira-code
      #  fira-mono
      fd
      gh
      go_1_23
      glow
      go-migrate
      gron
      gnused
      gnumake
      #htop # programs.htop
      hub
      #  hugo
      #  ipmitool
      inxi
      jetbrains-mono # font
      just
      jq
      killall
      lazydocker
      lazygit
      lsof
      mage
      mc
      mkdocs
      mosh
      neofetch
      nil # nix lsp
      nmap

      # qmk
      qmk
      ripgrep
      redis
      stern
      #  skopeo
      #  smartmontools
      #  terraform
      tree
      ttyplot
      unzip
      watch
      watchexec
      wget
      wireguard-tools
      viddy
      vim
      vscode
      yq
      zsh
      zsh-syntax-highlighting

      # requires nixpkgs.config.allowUnfree = true;
      vscode-extensions.ms-vscode-remote.remote-ssh

      # lib.optionals boolean stdenv is darwin
      #mas # mac app store cli

      (pkgs.python3.withPackages (python-pkgs: [
        python-pkgs.libtmux
        python-pkgs.requests
        python-pkgs.pytest
        python-pkgs.pyserial
      ]))
    ];
  };
}
