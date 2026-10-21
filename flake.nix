{
  description = "AI-agent 原生的 NixOS + Hyprland 发行版（P1：options + 多机型）";

  # 通道 tarball 输入：本机访问 github.com 会被阻断，改用清华镜像的 nixexprs。
  # 由 flake.lock 锁定 narHash，内容漂移会导致校验失败而不是静默变化。
  inputs.nixpkgs.url = "https://mirrors.tuna.tsinghua.edu.cn/nix-channels/nixos-26.05/nixexprs.tar.xz";

  # 个别组件需要比 stable 新的版本（hyprpolkitagent 0.2.0 = hyprtoolkit 实现，
  # 认证框配色可由 ~/.config/hypr/hyprtoolkit.conf 跟随主题），从 unstable 通道取。
  # 只引用单个包，二进制走清华镜像缓存，系统其余部分仍用 26.05。
  inputs.nixpkgs-unstable.url = "https://mirrors.tuna.tsinghua.edu.cn/nix-channels/nixos-unstable/nixexprs.tar.xz";
  inputs.nixpkgs-unstable.flake = false;

  outputs = { self, nixpkgs, nixpkgs-unstable }:
    let
      lib = nixpkgs.lib;

      # 自动发现 hosts/<name>/：以 _ 开头的目录（如 _template）是模板，不计入。
      hostEntries = builtins.readDir ./hosts;
      hosts = builtins.filter
        (n: hostEntries.${n} == "directory" && !(lib.hasPrefix "_" n))
        (builtins.attrNames hostEntries);

      # 注意：不能用 nixpkgs.lib.trivial.versionSuffix——flake 模式下的 lib 会被
      # lib/flake-version-info.nix 覆盖成 ".19800101.dirty"（tarball 无 git 元数据）。
      # 直接读 nixpkgs 自带的 .version-suffix 才能拿到 channel 的真实后缀。
      versionSuffix =
        lib.removeSuffix "\n" (builtins.readFile (nixpkgs + "/.version-suffix"));

      # 各机目标架构；未列出的默认 x86_64-linux。
      # aarch64 分支：virtio 虚机改为 aarch64，便于在 ARM 主机上构建/验证。
      hostSystems = {
        "vm-virtio" = "aarch64-linux";
      };
      systemFor = name: hostSystems.${name} or "x86_64-linux";

      mkHost = name: lib.nixosSystem {
        system = systemFor name;
        # unstable 只按需用于个别组件（distro.polkitAgent）。
        # 通道 tarball 没有 flake.nix，按路径 import 取包集；惰性求值不波及其它 host。
        specialArgs = {
          unstablePkgs = import nixpkgs-unstable {
            system = systemFor name;
            config.allowUnfree = true;
          };
        };
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

      # 用户级配置树（~/.config + ~/.local/bin），由 install.sh 软链到用户目录。
      homePkg = name:
        let
          c = self.nixosConfigurations.${name}.config;
        in
        import ./home/default.nix {
          inherit (nixpkgs) lib;
          inherit (c) distro;
          pkgs = self.nixosConfigurations.${name}.pkgs;
          home = c.users.users.${c.distro.user.name}.home;
          hostName = name;
        };

      # 按目标架构分组，生成 packages.<system> / checks.<system>
      hostsBySystem = builtins.groupBy (name: systemFor name) hosts;

      # 安装镜像：aarch64 分支产出 aarch64 ISO。
      isoSystem = "aarch64-linux";
      mkIso = system: (lib.nixosSystem {
        inherit system;
        modules = [
          "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
          ./installer/iso-config.nix
          { system.nixos.versionSuffix = versionSuffix; }
        ];
      }).config.system.build.isoImage;

      # live + install 一体盘：直接进入 Hyprland 桌面，并保留安装器
      mkLiveIso = system: (lib.nixosSystem {
        inherit system;
        modules = [
          "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
          ./installer/live-iso-config.nix
          { system.nixos.versionSuffix = versionSuffix; }
        ];
      }).config.system.build.isoImage;
    in
    {
      nixosConfigurations = lib.genAttrs hosts mkHost;

      packages = lib.mapAttrs
        (system: names:
          lib.genAttrs names homePkg
          // lib.optionalAttrs (system == isoSystem) { iso = mkIso system; liveIso = mkLiveIso system; })
        hostsBySystem;

      # nixosConfigurations 不会被 `nix flake check` 自动检查，显式放进 checks
      checks = lib.mapAttrs
        (system: names:
          lib.genAttrs names
            (name: self.nixosConfigurations.${name}.config.system.build.toplevel))
        hostsBySystem;
    };
}
