# nix-config

Repo contains configuration for personal machines, mostly running nix-darwin. Do not use without intense modifications.

```

# install nix
sh <(curl -L https://nixos.org/nix/install)

# Open new terminal

nix-shell -p git just
git clone --branch getting-started https://github.com/bcotton/nix-config.git 
cd nix-config
git mv hosts/darwin/bobs-laptop hosts/darwin/`hostname -s`

# make sure the hostname matches your darwin config in flake.nix and the dir name in `hosts/darwin`
just build

# fix any errors

just
```