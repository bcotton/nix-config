{
  config,
  pkgs,
  lib,
  ...
}: {
  users.groups = {
    llm-users = {};
  };
}
