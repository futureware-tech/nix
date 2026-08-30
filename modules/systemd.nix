{
  config,
  pkgs,
  lib,
  ...
}:
let
  mkNotifyService =
    { isUser, subject }:
    {
      description = "Send a notification about ${
        if isUser then "user " else ""
      }systemd unit %i ${lib.toLower subject}";
      serviceConfig.Type = "oneshot";
      scriptArgs = if isUser then "%i %u" else "%i";
      script = ''
        set -eu
        UNIT=$1
        IDENTIFIER=''${2:-system}

        ${config.security.wrapperDir}/sendmail -t <<MAIL
        To: root
        Subject: ${subject} ($IDENTIFIER): $UNIT
        Content-Transfer-Encoding: 8bit
        Content-Type: text/plain; charset=UTF-8

        $(${pkgs.systemd}/bin/systemctl ${if isUser then "--user" else ""} status --full "$UNIT")
        MAIL
      '';
    };
in
{
  systemd.services."notify-failed@" = mkNotifyService {
    isUser = false;
    subject = "Failure";
  };
  systemd.services."notify-succeeded@" = mkNotifyService {
    isUser = false;
    subject = "Success";
  };

  systemd.user.services."notify-failed@" = mkNotifyService {
    isUser = true;
    subject = "Failure";
  };
  systemd.user.services."notify-succeeded@" = mkNotifyService {
    isUser = true;
    subject = "Success";
  };
}
