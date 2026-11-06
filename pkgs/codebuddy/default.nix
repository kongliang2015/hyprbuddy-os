# codebuddy：腾讯 CodeBuddy CLI 的**官方原生构建**（单文件可执行）。
#
# 上游同时提供 npm 包（@tencent-ai/codebuddy-code，214 MB 解包 + 31 个依赖）
# 和原生构建（`codebuddy install` 使用的同一制品，发布于腾讯云 COS）。
# 这里改用原生构建：只有 1 个 tar.gz、无 node_modules、构建只需 patchelf。
#
# 分发规则（从官方 bundle 的 ReleasesService 反推并实测）：
#   <baseUrl>/latest                                  -> 版本号
#   <baseUrl>/download/<version>/codebuddy-code_<Platform>_<arch>.tar.gz
# 维护：升级时先 `curl <baseUrl>/latest` 取版本，再改 version + hash
# （`nix store prefetch-file --json <url> | jq -r .hash`）。
{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  glibc,
}:

let
  # 官方命名：Linux_x86_64 / Linux_arm64（macOS 为 Darwin_*，本仓库只声明 Linux）
  platform = if stdenv.hostPlatform.isAarch64 then "Linux_arm64" else "Linux_x86_64";
in
stdenv.mkDerivation rec {
  pname = "codebuddy";
  version = "2.180.0";

  src = fetchurl {
    url = "https://acc-1258344699.cos.accelerate.myqcloud.com/@tencent-ai/codebuddy-code/releases/download/${version}/codebuddy-code_${platform}.tar.gz";
    hash = "sha256-IlIr8bYG871I+25luLrxwa9koGrZfM8/A0Vt5uaS0c8=";
  };

  # 实测该二进制只动态链接 glibc（libc / libpthread / libdl / libm），
  # interp 是 /lib64 路径，NixOS 上必须 autoPatchelf。
  nativeBuildInputs = [ autoPatchelfHook ];
  buildInputs = [ glibc ];

  # tar 内只有 codebuddy / CHANGELOG.md / LICENSE.txt / README.md（平铺，无顶层目录）
  sourceRoot = ".";
  dontConfigure = true;
  dontBuild = true;
  dontStrip = true; # 170 MB 单文件，strip 收益小、耗时长

  installPhase = ''
    runHook preInstall
    install -Dm755 codebuddy $out/bin/codebuddy
    install -Dm644 LICENSE.txt $out/share/doc/codebuddy/LICENSE.txt
    runHook postInstall
  '';

  meta = {
    description = "Tencent CodeBuddy CLI (official native build)";
    homepage = "https://www.codebuddy.ai/";
    license = lib.licenses.unfree;
    mainProgram = "codebuddy";
    platforms = [ "x86_64-linux" "aarch64-linux" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
