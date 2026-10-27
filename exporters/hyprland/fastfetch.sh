#!/usr/bin/env bash
# fastfetch jsonc（主题名/位置烘焙，agent 用量现取）
# （P2 从 theme-next 拆分；由编排器 source，T_* 环境由 exporters/lib.sh 的 theme_env_load 提供）
# ── fastfetch（hypr-menu「系统信息」弹窗；配色随主题）──────────────
# 主题名/壁纸在写入时烘焙进去（切主题即重写），agent 用量与世代每次现取。
FFCFG=$XDG_CONFIG_HOME/fastfetch/config.jsonc
mkdir -p "$XDG_CONFIG_HOME/fastfetch"
THEME_POS=$((idx + 1))
cat > "$FFCFG.tmp.$$" <<FFCFG
{
  "\$schema": "https://github.com/fastfetch-cli/fastfetch/raw/master/doc/json_schema.json",
  "logo": {
    "type": "builtin",
    "source": "NixOS",
    "padding": { "right": 2 },
    "color": { "1": "#${T_ACCENT}", "2": "#${T_ACCENT2}" }
  },
  "display": {
    "separator": ": ",
    "color": { "keys": "#${T_ACCENT}", "output": "#${T_FG}", "separator": "#${T_INACTIVE}" }
  },
    "modules": [
    { "type": "title" },
    "separator",
    { "type": "command", "key": "OS", "text": "sysinfo-os" },
    "host",
    "kernel",
    "uptime",
    "packages",
    "shell",
    "display",
    "de",
    "wm",
    { "type": "command", "key": "Theme", "text": "echo '${T_NAME} (${THEME_POS}/${N})'" },
    { "type": "command", "key": "Agent", "text": "command -v agent-usage >/dev/null 2>&1 && agent-usage --text || true" },
    "icons",
    "font",
    "cursor",
    "terminal",
    "terminalfont",
    "cpu",
    "gpu",
    "memory",
    "swap",
    "disk",
    "localip",
    "battery",
    "poweradapter",
    "locale"
  ]
}
FFCFG
if [ -s "$FFCFG.tmp.$$" ]; then
  mv -f "$FFCFG.tmp.$$" "$FFCFG"
else
  rm -f "$FFCFG.tmp.$$"
fi
