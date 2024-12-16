{
  description = "Multi-channel Nixpkgs flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    utils.url = "github:numtide/flake-utils";

    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-24.11";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-unfree.url = "github:numtide/nixpkgs-unfree?ref=nixos-unstable";
    nixpkgs-master.url = "github:nixos/nixpkgs/master";
  };

  outputs =
    {
      self,
      nixpkgs,
      utils,
      ...
    }@inputs:
    let
      inherit (nixpkgs) lib;

      prepareNixpkgsInputLegacy = name: input: system: {
        name = lib.removePrefix "nixpkgs-" name;
        pkgs = input.legacyPackages.${system};
        inherit (input.legacyPackages.${system}) lib;
        inherit (input.legacyPackages.${system}.lib) version;
        inherit system;
        _input = input;
      };

      prepareNixpkgsInputEval =
        name: input: system:
        let
          pkgs = import input {
            inherit system;
            config = { };
            overlays = [ ];
          };
        in
        {
          name = lib.removePrefix "nixpkgs-" name;
          inherit system pkgs;
          inherit (pkgs) lib;
          inherit (pkgs.lib) version;
        };

      prepareNixpkgsInput = prepareNixpkgsInputLegacy;

      prepareAllNixpkgsInputs =
        system:
        lib.listToAttrs (
          map (
            name:
            lib.nameValuePair (lib.removePrefix "nixpkgs-" name) (
              prepareNixpkgsInput name inputs.${name} system
            )
          ) availableChannels
        );

      availableChannels = lib.attrNames (lib.filterAttrs (n: _: lib.hasPrefix "nixpkgs" n) inputs);

      channelNames = map (lib.removePrefix "nixpkgs-") availableChannels;
      channelsFor = system: lib.fix (_: prepareAllNixpkgsInputs system);

      getChannelByNameSafe =
        channels: name:
        channels.${"nixpkgs-" + name} or channels.${name} or (throw "Unknown channel: ${name}");

      getChannel =
        system: name:
        let
          channels = channelsFor system;
        in
        getChannelByNameSafe channels name;

      withChannels =
        system: default: f:
        let
          allChannels = channelsFor system;
          channels = allChannels // {
            default = getChannelByNameSafe allChannels default;
          };
        in
        f channels;

      channels = lib.genAttrs channelNames (name: name);

      importChannel =
        channel:
        {
          system ? channel.system,
          overlays ? [ ],
          config ? { },
        }@args:
        import channel._input args;

      makeChannelInstance =
        channel: f:
        let
          pkgs = importChannel channel { };
        in
        f pkgs channel.system pkgs.lib;

    in
    {
      inherit
        withChannels
        makeChannelInstance
        importChannel
        channelNames
        channels
        ;
      lib = {
        inherit getChannel;
      };
    };
}
