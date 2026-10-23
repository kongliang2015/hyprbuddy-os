# codebuddy：npm 上的 AI agent CLI（@tencent-ai/codebuddy-code）。
# nixpkgs 没有这个包，直接从 npm registry 打包，避免每台机器手工 npm install -g。
#
# 维护：升级版本时改 version + src.hash，然后用 lib.fakeHash 跑一次 build，
# 从报错里取新的 npmDepsHash（node_modules 由 lockfile 决定）。
{
  lib,
  buildNpmPackage,
  fetchurl,
  nodejs,
}:

buildNpmPackage rec {
  pname = "codebuddy";
  version = "2.173.0";

  src = fetchurl {
    # npmmirror 国内镜像（npmjs.org 直连 Cloudflare 易卡死）；内容与官方 registry 一致
    url = "https://registry.npmmirror.com/@tencent-ai/codebuddy-code/-/codebuddy-code-${version}.tgz";
    hash = "sha256-vC2xVH18Hb0slsooQ7pqbWamKuEQeAPhe8XcbOccLCE=";
  };

  # registry 的 tarball 解包后根目录是 package/
  sourceRoot = "package";

  # registry tarball 不带 lockfile；仓库里存一份供 fetchNpmDeps 使用
  postPatch = ''
    cp ${./package-lock.json} package-lock.json
  '';

  npmDepsHash = "sha256-88CpnPER9sTRnPNPBFdUiwMjNZ7dxkV6HfT1YCZIZPw=";

  # 包内自带 dist/ 构建产物，无需再 npm run build
  dontNpmBuild = true;

  # bin/codebuddy 是 #!/usr/bin/env node 脚本
  makeWrapperArgs = [
    "--prefix"
    "PATH"
    ":"
    (lib.makeBinPath [ nodejs ])
  ];

  meta = {
    description = "Tencent CodeBuddy CLI (AI coding agent)";
    homepage = "https://www.codebuddy.ai/";
    license = lib.licenses.unfree;
    mainProgram = "codebuddy";
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
  };
}
