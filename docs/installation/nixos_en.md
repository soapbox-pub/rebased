# Installing on NixOS

NixOS contains a source build package of pleroma and a NixOS module to install it.
For installation add this to your configuration.nix and add a config.exs next to it:
```nix
  services.pleroma = {
    enable = true;
    configs = [ (lib.fileContents ./config.exs) ];
    secretConfigFile = "/var/lib/pleroma/secret.exs";
  };
```

## Questions
The nix community uses matrix for communication: [#nix:nixos.org](https://matrix.to/#/#nix:nixos.org)

