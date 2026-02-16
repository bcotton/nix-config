# Git configuration module
# Extracted from bcotton.nix for better organization
{pkgs, ...}: {
  programs.git = {
    enable = true;
    settings = {
      user = {
        email = "bob.cotton@gmail.com";
        name = "Bob Cotton";
      };
      alias = {
        br = "branch";
        co = "checkout";
        ci = "commit";
        d = "diff";
        dc = "diff --cached";
        st = "status";
        la = "config --get-regexp alias";
        lg = "log --color --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr)%C(bold blue)<%an>%Creset' --abbrev-commit";
        lga = "log --color --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr)%C(bold blue)<%an>%Creset' --abbrev-commit --all";
        clone-gwt = "!sh $HOME/.config/git-worktrees/git-clone-bare-for-worktrees.sh";
        beads-init = "!sh $HOME/.config/beads-init/beads-init.sh";
      };
      url = {
        "ssh://git@github.com/" = {
          insteadOf = "https://github.com/";
        };
      };
      init.defaultBranch = "main";
      pager.difftool = true;

      core = {
        whitespace = "trailing-space,space-before-tab";
      };
      merge.conflictstyle = "diff3";
      diff = {
        colorMoved = "default";
      };
    };
    includes = [
      {path = "${pkgs.delta}/share/themes.gitconfig";}
    ];
  };
  programs.difftastic = {
    enable = false;
    options = {
      background = "dark";
      display = "side-by-side";
    };
  };
  programs.delta = {
    enable = true;
    enableGitIntegration = true;
    options = {
      features = "collared-trogon";
      navigate = true;
      light = false;
      side-by-side = true;
    };
  };
}
