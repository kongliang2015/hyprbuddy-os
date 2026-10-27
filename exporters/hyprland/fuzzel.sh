#!/usr/bin/env bash
# fuzzel [colors] 段替换（摘 store 软链，临时文件非空才落盘）
# （P2 从 theme-next 拆分；由编排器 source，T_* 环境由 exporters/lib.sh 的 theme_env_load 提供）
# ── fuzzel 启动器（替换 [colors] 段，其余保持仓库配置） ──
# fuzzel 即用即读配置，无需重启。fuzzel.ini 默认是 store 软链，摘链后写常规文件。
FUZZEL="$XDG_CONFIG_HOME/fuzzel/fuzzel.ini"
if [ -f "$FUZZEL" ]; then
  if [ -L "$FUZZEL" ]; then FSRC=$(readlink -f "$FUZZEL"); else FSRC="$FUZZEL"; fi
  mkdir -p "$XDG_CONFIG_HOME/fuzzel"
  # 先写临时文件，非空才替换（store 中间链接未就绪等异常时不留 0 字节配置）
  awk -v bg="${T_BG}ff" -v fg="${T_FG}ff" -v mtc="${T_FG}ff" \
      -v sel="${T_SURFACE}ff" -v seltxt="${T_FG}ff" -v selmtc="${T_BAR_PULSE}ff" \
      -v border="${T_FG}ff" '
    /^\[colors\]/ { inblk=1
      print "[colors]"
      print "background=" bg
      print "text=" fg
      print "match=" mtc
      print "selection=" sel
      print "selection-text=" seltxt
      print "selection-match=" selmtc
      print "border=" border
      next }
    /^\[/ { inblk=0 }
    !inblk { print }
  ' "$FSRC" > "$FUZZEL.tmp" 2>/dev/null || true
  if [ -s "$FUZZEL.tmp" ]; then
    mv -f "$FUZZEL.tmp" "$FUZZEL"
  else
    rm -f "$FUZZEL.tmp"
  fi
fi
