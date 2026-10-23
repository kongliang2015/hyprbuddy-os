# Plymouth 主题：assets/plymouth/splash.png + 彩色进度条（script 引擎）
# 进度条素材在构建期用 ImageMagick 生成：8 段 catppuccin 强调色拼成渐变，
# 模糊掉接缝，再用圆角 alpha 蒙版裁成胶囊形。
{ lib, stdenv, imagemagick }:

stdenv.mkDerivation {
  pname = "plymouth-theme-hyprbuddy";
  version = "1.0";

  src = ../../assets/plymouth;

  nativeBuildInputs = [ imagemagick ];
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    theme=$out/share/plymouth/themes/hyprbuddy
    mkdir -p "$theme"

    # 主图：等比缩到 1280 宽以内，控制 initrd 体积
    magick "$src/splash.png" -resize '1280x>' /tmp/logo.png

    # 边缘羽化：外围 12% 向内渐隐到全黑，消除方形边界（背景是纯黑，故淡出即无缝）
    # 注意 %w %h 后必须带 \n：read 遇到无换行 EOF 会返回 1，set -e 下静默中断
    read -r w h < <(magick /tmp/logo.png -format '%w %h\n' info:)
    inset=$(( w * 12 / 100 ))
    radius=$(( w / 14 ))
    magick -size "''${w}x''${h}" xc:black -fill white \
      -draw "roundrectangle ''${inset},''${inset} $(( w - inset )),$(( h - inset )) ''${radius},''${radius}" \
      -blur 0x$(( w / 22 )) /tmp/feather.png
    magick /tmp/logo.png /tmp/feather.png -alpha off -compose CopyOpacity -composite \
      -background black -alpha remove -alpha off "$theme/splash.png"

    barw=960
    barh=14

    # 彩色渐变条：8 段 catppuccin 强调色，拼接后模糊接缝
    colors=(89B4FA 74C7EC 89DCEB A6E3A1 F9E2AF FAB387 F38BA8 CBA6F7)
    for i in ''${!colors[@]}; do
      magick -size 120x''${barh} "xc:#''${colors[$i]}" "/tmp/strip-$i.png"
    done
    magick /tmp/strip-0.png /tmp/strip-1.png /tmp/strip-2.png /tmp/strip-3.png \
           /tmp/strip-4.png /tmp/strip-5.png /tmp/strip-6.png /tmp/strip-7.png \
           +append -blur 0x9 /tmp/bar-raw.png

    # 胶囊形蒙版
    magick -size ''${barw}x''${barh} xc:none -fill white \
      -draw 'roundrectangle 0,0 959,13 7,7' /tmp/mask.png

    # 填充条
    magick /tmp/bar-raw.png /tmp/mask.png -alpha off -compose CopyOpacity -composite "$theme/bar.png"
    # 轨道：同形状、半透明白
    magick -size ''${barw}x''${barh} "xc:rgba(255,255,255,0.13)" /tmp/track-src.png
    magick /tmp/track-src.png /tmp/mask.png -alpha off -compose CopyOpacity -composite "$theme/track.png"

    # 光点
    magick -size 56x56 radial-gradient:white-none "$theme/glow.png"

    install -m 0644 ${./hyprbuddy.plymouth} "$theme/hyprbuddy.plymouth"
    install -m 0644 ${./hyprbuddy.script} "$theme/hyprbuddy.script"
    substituteInPlace "$theme/hyprbuddy.plymouth" --replace-fail "@THEME_DIR@" "$theme"

    runHook postInstall
  '';

  meta = with lib; {
    description = "Plymouth theme for HyprBuddy: splash image + colorful progress bar";
    platforms = platforms.linux;
  };
}
