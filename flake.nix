{
  description = "AI-agent 原生的 NixOS + Hyprland 发行版（P0：flake 化）";

  # 通道 tarball 输入：本机访问 github.com 会被阻断，改用清华镜像的 nixexprs。
  # 由 flake.lock 锁定 narHash，内容漂移会导致校验失败而不是静默变化。
  inputs.nixpkgs.url = "https://mirrors.tuna.tsinghua.edu.cn/nix-channels/nixos-26.05/nixexprs.tar.xz";

  outputs = { self, nixpkgs }:
    let
      # tarball 输入没有 git 元数据，NixOS 会把 versionSuffix 退化成
      # ".19800101.dirty"；这里取回 nixpkgs 自带的 .version-suffix，使
      # flake 构建与 channel 构建的 nixos-version / label 完全一致。
      # 注意：不能用 nixpkgs.lib.trivial.versionSuffix——flake 模式下的 lib 会被
      # lib/flake-version-info.nix 覆盖成 ".19800101.dirty"（tarball 无 git 元数据）。
      # 直接读 nixpkgs 自带的 .version-suffix 才能拿到 channel 的真实后缀。
      versionSuffix =
        nixpkgs.lib.removeSuffix "\n" (builtins.readFile (nixpkgs + "/.version-suffix"));

      mkHost = name: nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./hosts/${name}/default.nix
          { system.nixos.versionSuffix = versionSuffix; }
        ];
      };
    in
    {
      nixosConfigurations.leonard = mkHost "leonard";

      # nixosConfigurations 不会被 `nix flake check` 自动检查，显式放进 checks
      checks.x86_64-linux.leonard-toplevel =
        self.nixosConfigurations.leonard.config.system.build.toplevel;
    };
}
