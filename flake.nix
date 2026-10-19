{
  description = "AI-agent 原生的 NixOS + Hyprland 发行版（P1：options + 多机型）";

  # 通道 tarball 输入：本机访问 github.com 会被阻断，改用清华镜像的 nixexprs。
  # 由 flake.lock 锁定 narHash，内容漂移会导致校验失败而不是静默变化。
  inputs.nixpkgs.url = "https://mirrors.tuna.tsinghua.edu.cn/nix-channels/nixos-26.05/nixexprs.tar.xz";

  outputs = { self, nixpkgs }:
    let
      # 自动发现 hosts/<name>/：以 _ 开头的目录（如 _template）是模板，不计入。
      hostEntries = builtins.readDir ./hosts;
      hosts = builtins.filter
        (n: hostEntries.${n} == "directory" && !(nixpkgs.lib.hasPrefix "_" n))
        (builtins.attrNames hostEntries);

      # 注意：不能用 nixpkgs.lib.trivial.versionSuffix——flake 模式下的 lib 会被
      # lib/flake-version-info.nix 覆盖成 ".19800101.dirty"（tarball 无 git 元数据）。
      # 直接读 nixpkgs 自带的 .version-suffix 才能拿到 channel 的真实后缀。
      versionSuffix =
        nixpkgs.lib.removeSuffix "\n" (builtins.readFile (nixpkgs + "/.version-suffix"));

      mkHost = name: nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./modules/default.nix
          ./hosts/${name}/default.nix
          { system.nixos.versionSuffix = versionSuffix; }
          # 仓库自带的包（nixpkgs 没有的），通过 overlay 暴露为 pkgs.<name>
          {
            nixpkgs.overlays = [
              (final: _prev: {
                codebuddy = final.callPackage ./pkgs/codebuddy { };
              })
            ];
          }
        ];
      };
    in
    {
      nixosConfigurations = nixpkgs.lib.genAttrs hosts mkHost;

      # 用户级配置树（~/.config + ~/.local/bin），由 install.sh 软链到用户目录。
      # 放在 packages 下而不是自定义 output（flake 只认已知 output 名）。
      packages.x86_64-linux = nixpkgs.lib.genAttrs hosts (name:
        let
          c = self.nixosConfigurations.${name}.config;
        in
        import ./home/default.nix {
          inherit (nixpkgs) lib;
          inherit (c) distro;
          pkgs = self.nixosConfigurations.${name}.pkgs;
          home = c.users.users.${c.distro.user.name}.home;
          hostName = name;
        })
      // {
        iso = (nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
            ./installer/iso-config.nix
            { system.nixos.versionSuffix = versionSuffix; }
          ];
        }).config.system.build.isoImage;
      };

      # nixosConfigurations 不会被 `nix flake check` 自动检查，显式放进 checks
      checks.x86_64-linux = builtins.listToAttrs (map (name: {
        name = "${name}-toplevel";
        value = self.nixosConfigurations.${name}.config.system.build.toplevel;
      }) hosts);
    };
}
