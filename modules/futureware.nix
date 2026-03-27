# This module is supposed to be used on internal FutureWare servers.

{
  programs.git.enable = true;
  programs.git.config = {
    url."https://git.sheremet.ch/futureware-tech/nix.git".insteadOf =
      "https://github.com/futureware-tech/nix.git";
  };
}
