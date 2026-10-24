# SDDM 主题：HyprBuddy 风格（深黑底 + 主视觉背景 + 霓虹青/品红渐变卡片）。
# 背景图在构建期从 wallpapers/10-hyprbuddy.png 缩放生成，与 Plymouth 主题同源。
{
  lib,
  stdenv,
  imagemagick,
}: stdenv.mkDerivation {
  pname = "sddm-theme-hyprbuddy";
  version = "1.0";
  src = ./.;
  dontBuild = true;
  nativeBuildInputs = [ imagemagick ];
  installPhase = ''
    runHook preInstall
    theme=$out/share/sddm/themes/hyprbuddy
    mkdir -p "$theme"
    install -m 0644 ${./metadata.desktop} "$theme/metadata.desktop"
    install -m 0644 ${./theme.conf} "$theme/theme.conf"
    install -m 0644 ${./Main.qml} "$theme/Main.qml"
    # 背景：主视觉壁纸缩到 1920 宽，去掉 alpha（greeter 无需透明）
    magick ${../../wallpapers/10-hyprbuddy.png} -resize '1920x>' -alpha off -depth 8 "$theme/background.png"
    runHook postInstall
  '';
  meta = with lib; {
    description = "SDDM theme for HyprBuddy: dark greeter with neon cyan/magenta gradient";
    platforms = platforms.linux;
  };
}
