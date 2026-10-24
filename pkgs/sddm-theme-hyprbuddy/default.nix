# SDDM 主题：HyprBuddy 风格（深黑底 + 主视觉背景 + 霓虹青/品红渐变卡片）。
# 背景图在构建期从 wallpapers/10-hyprbuddy.png 缩放 + 边缘羽化（渐隐到透明，
# 配合 QML 深色底消除图片方形边缘接缝），与 Plymouth 主题同源。
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
    # 背景：缩到 1920 宽，边缘 6% 羽化渐隐到透明。
    # 注意 %w %h 后必须带换行：read 遇到无换行 EOF 会返回 1，set -e 下静默中断。
    magick ${../../wallpapers/10-hyprbuddy.png} -resize '1920x>' -alpha off /tmp/bg.png
    read -r w h < <(magick /tmp/bg.png -format '%w %h\n' info:)
    inset=$(( w * 8 / 100 ))
    magick -size "''${w}x''${h}" xc:black -fill white \
      -draw "roundrectangle $inset,$inset $(( w - inset )),$(( h - inset )) $(( w / 10 )),$(( w / 10 ))" \
      -blur 0x$(( w / 8 )) /tmp/feather.png
    magick /tmp/bg.png /tmp/feather.png -alpha off -compose CopyOpacity -composite \
      "$theme/background.png"
    runHook postInstall
  '';
  meta = with lib; {
    description = "SDDM theme for HyprBuddy: dark greeter with neon cyan/magenta gradient";
    platforms = platforms.linux;
  };
}
