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

    (python3.withPackages (py: [
      py.llm
      py.llm-ollama
    ]))

  ];

  # Share Mounts
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

    fileSystems."/mnt/musica" = {
    device = "192.168.1.51:/volume1/music/MusicLibrary";  # ← change this if your NFS export path is different
    fsType = "nfs";
    options = [ "noauto,x-systemd.automount,nofail,_netdev" ];
  };
 
  ######################
# Docker configuration

  virtualisation.docker = {
    enable = true;
  };

  virtualisation.oci-containers = {
    backend = "docker";
    containers = {

      openspeedtest = {
        image = "openspeedtest/latest";
        ports = [ "3000:3000" ];
        autoStart = true;
      };

      portainer = {
        image = "portainer/portainer-ce:latest";
        ports = [ "9000:9000" ];
        volumes = [
          "/var/lib/portainer:/data"
          "/run/docker.sock:/var/run/docker.sock"
        ];
        autoStart = true;
      };
    };
  };

  ####### End Docker config
  #########################

  # VS Code Server
  # Needed to connect VS Code (duh)
  services.vscode-server.enable = true;

  # Tailscale (advertise as exit node)
  services.tailscale = {
    enable = true;
    extraUpFlags = [ "--advertise-exit-node" "--advertise-routes=0.0.0.0/0,::/0" ];
  };

  ########################
  ######### Plex #########

  services.plex = {
    enable = true;
    openFirewall = true;  # if you want remote access
    # dataDir = "/var/lib/plex";  # default, but make sure it is persisted
  };

  # Very important: Plex needs the prefs file to be writable by the plex user
  systemd.services.plex = {
    serviceConfig.StateDirectory = "plexmediaserver";
    serviceConfig.StateDirectoryMode = "0755";
  };

  # Make sure the directories are owned correctly and survive reboots
  systemd.tmpfiles.rules = [
    "d /var/lib/plexmediaserver 0755 plex plex -"
    "d /var/lib/plexmediaserver/Library 0755 plex plex -"
    "d /var/lib/plexmediaserver/Library/Application\\ Support 0755 plex plex -"
    "d /var/www/share 2775 root users"  # this one is for filebrowser
  ];

  #### End Plex #################
  ###############################

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
    80    # Ollama
    8000  # OpenSpeedTest
    7860  # Ollama
    9000  # Portainer
    8080  # Filebrowser
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
