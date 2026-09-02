/*
  Creating a new ZFS pool:

    % POOLNAME=tank

  Find out the best recordsize value. 64K for databases and configs, 1M for
  large data chunks such as photos and videos.

    % RECORDSIZE=64K

  Create a key:

    % KEYPATH=$(mktemp)
    % od -Anone -x -N 32 -w64 /dev/random | tr -d [:blank:] > "${KEYPATH?}"

  # cat "${KEYPATH?}" | zpool create \
      -O compression=lz4 \
      -O xattr=sa \
      -O atime=off \
      -O dedup=off \
      -O acltype=off \
      -O encryption=on \
      -O keyformat=hex \
      -o autoexpand=off \
      -O mountpoint=legacy \
      -O recordsize="${RECORDSIZE?}" \
      -o ashift=12 \
      "${POOLNAME?}" mirror /dev/disk/by-id/{id1,id2}

  compression: lz4 is fast enough.
  xattr: xattr must be enabled for "chattr" (set immutability) and "setcap"
          (ping) to work. "sa" is fast, "on" is slow.
  atime: faster access time when disabled. Can be specified as mount option
          instead.
  dedup: very slow, disable.
  acltype: this is for having a list of granular access with setfacl, instead
            of the owner/group/others UNIX model. We don't use that, disable.
            If you happened to enable it before, change to off, but this isn't
            retroactive - you have to "setfacl --remove-all --recursive /path".
            See also https://www.truenas.com/community/threads/37046/
  encryption: enable encryption at the pool level, which does nothing else
              than storing the parameters. Only datasets themselves are
              encrypted, and can be chosen for each of them.
  autoexpand: do not automatically expand the pool to fit the size of attached
              devices. This will hurt if you detach a smaller device and then
              try to re-attach it! zpool size CAN NOT be reduced.
  ashift: use 12 because all SSDs are tuned for 4096 block size.
          https://openzfs.github.io/openzfs-docs/Performance%20and%20Tuning/Hardware.html#flash-pages
          Previously, this manual recommended ashift = log2 PHY-SEC from
          lsblk -o NAME,PHY-SEC.
  mountpoint: we mount via NixOS config, not automatically in ZFS.

  Default options:
    autotrim=off because we run a trim service instead. Continuous trimming
                  can be destructive for some SSD drives.

  Use "zdb -C" to get current values such as ashift.

  Upon creating the pool:
    1. "chattr +i" the directory where you are mounting it, to avoid writing
       data there before the pool is mounted.
    2. create a 20% reservation to prevent performance deterioration (on zfs
       occurs when free space goes below 20%):

        # zfs create \
            -o encryption=off \
            -o refreservation=10G \
            -o mountpoint=none \
            -o canmount=off \
            "${POOLNAME?}/reserved"
    3. add the pool to fileSystems
    4. consider adding the pool to services.sanoid.datasets for auto-snapshot

  Creating a new ZFS filesystem:

  # zfs create "${POOLNAME?}/myfs"

  mountpoint: see above.
  encryption: set to "off" to disable encryption for this dataset
              specifically.

  Remember to "chattr +i" (see above) and add to fileSystems.

  To check config of an existing pool or filesystem, use:
    % zfs get all -s local -t filesystem -r "${POOLNAME?}"
*/

{ lib, pkgs, ... }:
{
  services.zfs = {
    trim = {
      enable = true;
      interval = "Mon 22:00";
      randomizedDelaySec = "1min";
    };
    autoScrub = {
      enable = true;
      interval = "*-*-01 23:00";
      randomizedDelaySec = "1min";
    };

    zed.settings = {
      ZED_EMAIL_ADDR = [ "root" ];
      ZED_NOTIFY_VERBOSE = true;

      ZED_USE_ENCLOSURE_LEDS = true;
      ZED_SCRUB_AFTER_RESILVER = true;
    };
  };
  # TODO: raise a PR to nixpkgs to add options to services.zfs.trim
  systemd.services.zpool-trim.serviceConfig.ExecStart =
    lib.mkForce "${pkgs.runtimeShell} -c 'for pool in $(zpool list -H -o name); do zpool trim -r 100MB $pool;  done || true' ";

  services.sanoid = {
    enable = true;
    interval = "*:0/15"; # For "frequently" snapshots.
    templates = {
      "default" = {
        frequently = 8; # Keep this many snapshots @15min frequency.
        hourly = 48;
        daily = 90;
        weekly = 30;
        monthly = 24;
        yearly = 100;
      };
    };
  };

  # https://openzfs.github.io/openzfs-docs/Project%20and%20Community/FAQ.html#selecting-dev-names-when-creating-a-pool-linux
  # Default /dev/disk/by-id doesn't work on VM, but /dev/disk/by-uuid could.
  boot.zfs.devNodes = lib.mkDefault "/dev/disk/by-path";
  # We set forceImportRoot to true because our servers have exclusive access to
  # their local disks (no SANs/iSCSI). This guarantees they can recover and boot
  # unattended after a sudden power loss or hard crash, instead of hanging
  # indefinitely in an emergency shell waiting for manual intervention.
  boot.zfs.forceImportRoot = true;
}
