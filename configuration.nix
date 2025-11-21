# /etc/nixos/configuration.nix
{ config, pkgs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    (fetchTarball "https://github.com/nix-community/nixos-vscode-server/tarball/master")
  ];

  # Bootloader
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Time zone
  time.timeZone = "America/Chicago";

  # Nix settings
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Unfree packages (Plex, etc.)
  nixpkgs.config.allowUnfree = true;

  # Networking
  networking.hostName = "nixos";
  networking.networkmanager.enable = true;

  networking.interfaces.eth0.ipv4.addresses = [{
    address = "192.168.1.52";
    prefixLength = 24;
  }];
  networking.defaultGateway = "192.168.1.1";
  networking.nameservers = [ "192.168.1.1" ];

  # IP forwarding (Tailscale exit node)
  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 1;
    "net.ipv6.conf.all.forwarding" = 1;
  };

  # Packages
  environment.systemPackages = with pkgs; [
    vim git wget curl tailscale cifs-utils parted cloud-utils
    e2fsprogs xfsprogs btrfs-progs util-linux php
  ];

  # Mounts
  fileSystems."/mnt/videoz" = {
    device = "192.168.1.51:/volume1/Video";  # ← change this if your NFS export path is different
    fsType = "nfs";
    options = [ "noauto,x-systemd.automount,nofail,_netdev" ];
  };
  
  fileSystems."/mnt/intshare" = {
    device = "192.168.1.51:/volume1/InternalShare";  # ← change this if your NFS export path is different
    fsType = "nfs";
    options = [ "noauto,x-systemd.automount,nofail,_netdev" ];
  };

  # Podman configuration
  virtualisation.oci-containers.backend = "podman";

  # Declarative OCI containers (Podman) – the modern way
  virtualisation.oci-containers.containers = {
    
    openspeedtest = {
      image = "openspeedtest/latest";
      ports = [ "3000:3000" ];
      autoStart = true;
    };

    portainer = {
      image = "portainer/portainer-ce:latest";
      ports = [ "9000:9000" "8000:8000" ];
      volumes = [
        "/var/lib/portainer:/data"
        "/run/podman/podman.sock:/var/run/docker.sock"
      ];
      autoStart = true;
    };

    # End of Podman containers
  };

  # VS Code Server
  # Needed to connect VS Code (duh)
  services.vscode-server.enable = true;

  # Tailscale (advertise as exit node)
  services.tailscale = {
    enable = true;
    extraUpFlags = [ "--advertise-exit-node" "--advertise-routes=0.0.0.0/0,::/0" ];
  };

  # Plex
  services.plex = {
    enable = true;
    openFirewall = true;  # if you want remote access
    # dataDir = "/var/lib/plex";  # default, but make sure it is persisted
  };

  # Make sure the directory is owned correctly and survives reboots
  systemd.tmpfiles.rules = [
    "d /var/lib/plexmediaserver 0755 plex plex -"
    "d /var/lib/plexmediaserver/Library 0755 plex plex -"
    "d /var/lib/plexmediaserver/Library/Application\\ Support 0755 plex plex -"
  ];

  # Very important: Plex needs the prefs file to be writable by the plex user
  systemd.services.plex = {
    serviceConfig.StateDirectory = "plexmediaserver";
    serviceConfig.StateDirectoryMode = "0755";
  };

  # User account
  users.users.bigjoetx = {
    isNormalUser = true;
    extraGroups = [ "wheel" "podman" "plex" "docker"];
    hashedPassword = "<hashed-password>";
  };

  # SSH
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "yes";
      PasswordAuthentication = true;
    };
  };
 
  # Firewall
  networking.firewall.enable = true;
  networking.firewall.allowedTCPPorts = [
    22    # SSH
    80    # FileBrowser
    3000  # OpenSpeedTest
    9000  # Portainer
    8080  # (if you use it somewhere)
    32400 # Plex
    32469 # Plex DLNA
    8324  # Plex
  ];
  networking.firewall.allowedUDPPorts = [
    1900 32410 32412 32413 32414 # Plex discovery
  ];

  # DO NOT CHANGE after initial install
  system.stateVersion = "25.05";
}