#!/usr/bin/env bash
# 安装器：探测硬件 → 生成 host 配置 → 求值 → nixos-install。
#
# 设计约束：本脚本【不分区、不格式化】。它假定 $TARGET 已是挂载好的 NixOS 根分区；
# 分区交给 disko 或手动操作，避免"一条命令抹掉整块盘"。
set -euo pipefail

here="$(cd "$(dirname "$0")/.." && pwd)"

TARGET=/mnt
HOST_NAME=""
USER_NAME=""
STATE_VERSION=25.11
SESSIONS=""
AGENT_ENABLE=true
AGENT_LIST=""
LAZY_AGENT_LIST=""
AGENT_CANDIDATES="codebuddy opencode codex claude-code aider-chat"
LAZY_DEFAULT="codex claude-code opencode"
MIRROR=cn
MIRROR_CANDIDATES="cn tuna sjtu ustc official"
ASSUME_YES=0
DRY_RUN=0

die() { echo "错误: $*" >&2; exit 1; }
say() { printf '\n==> %s\n' "$*"; }

usage() {
  cat <<'EOF'
用法: install.sh [选项]

  --target <挂载点>      安装目标（默认 /mnt，须已挂载并格式化）
  --hostname <名字>      主机名（默认取探测到的 hostname）
  --user <名字>          主用户（默认 logname，其次 nixos）
  --state-version <版本> system.stateVersion（默认 25.11）
  --sessions "xfce windowmaker"   额外保留的 X11 会话
  --agents "codebuddy opencode"   预装哪些 agent（空格分隔；不给则交互选择，空=全部懒加载）
  --mirror <name>        二进制缓存源：cn（默认）/ tuna / sjtu / ustc / official
  --no-agent             不安装 agent 层
  --yes                  跳过确认
  --dry-run              只渲染 + 求值，不写目标盘

注意：本脚本不负责分区/格式化。请先自行分区、mkfs、挂载到 --target。
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --target) TARGET="${2:?}"; shift 2 ;;
    --hostname) HOST_NAME="${2:?}"; shift 2 ;;
    --user) USER_NAME="${2:?}"; shift 2 ;;
    --state-version) STATE_VERSION="${2:?}"; shift 2 ;;
    --sessions) SESSIONS="${2:-}"; shift 2 ;;
    --agents) AGENT_LIST="${2:-}"; shift 2 ;;
    --mirror) MIRROR="${2:?}"; shift 2 ;;
    --no-agent) AGENT_ENABLE=false; shift ;;
    --yes) ASSUME_YES=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "未知参数: $1" ;;
  esac
done

[ "$(id -u)" -eq 0 ] || die "需要 root（用 sudo 运行）"

say "探测硬件"
detect_env="$(mktemp)"
"$here/installer/detect.sh" > "$detect_env"
# shellcheck disable=SC1090
. "$detect_env"
rm -f "$detect_env"

: "${HOST_NAME:=${HOSTNAME:-nixos}}"
: "${USER_NAME:=${SUDO_USER:-nixos}}"

# ISO 内置 nixpkgs：安装阶段用 path: 覆盖 flake 输入，避免依赖 flake 输入网络。
# ISO 内的 nixpkgs 就是 flake.lock 锁定的那一份（narHash 一致），不会换版本。
NIXPKGS_LOCAL="${NIXPKGS_LOCAL:-}"
if [ -z "$NIXPKGS_LOCAL" ]; then
  for p in /run/current-system/sw/share/hyprbuddy-nixpkgs "$here/nixpkgs"; do
    if [ -f "$p/flake.nix" ]; then NIXPKGS_LOCAL="$p"; break; fi
  done
fi

# 交互选择预装 agent（--yes 或非 TTY 时跳过，走 --agents / 全懒加载）
if [ "$ASSUME_YES" -ne 1 ] && [ -t 0 ]; then
  printf "\n可选 agent：%s\n" "$AGENT_CANDIDATES"
  printf "要预装哪些？（空格分隔，回车=全部懒加载）: "
  read -r AGENT_LIST
fi

# 交互选择二进制缓存源（同样仅 TTY 且非 --yes）
if [ "$ASSUME_YES" -ne 1 ] && [ -t 0 ]; then
  printf "\n可选软件源：%s（默认 cn）\n" "$MIRROR_CANDIDATES"
  printf "选择源 [cn]: "
  read -r m
  [ -n "$m" ] && MIRROR="$m"
fi

case " $MIRROR_CANDIDATES " in
  *" $MIRROR "*) ;;
  *) die "未知软件源: $MIRROR（可选: $MIRROR_CANDIDATES）" ;;
esac

for a in $AGENT_LIST; do
  case " $AGENT_CANDIDATES " in
    *" $a "*) ;;
    *) die "未知 agent: $a（可选: $AGENT_CANDIDATES）" ;;
  esac
done

# 差集：懒加载默认里去掉已预装的
for a in $LAZY_DEFAULT; do
  case " $AGENT_LIST " in
    *" $a "*) ;;
    *) LAZY_AGENT_LIST="$LAZY_AGENT_LIST $a" ;;
  esac
done
LAZY_AGENT_LIST="${LAZY_AGENT_LIST# }"

# --no-agent 时清空两个列表，避免渲染出 enable=false 却列着 agent 的配置
if [ "$AGENT_ENABLE" = false ]; then AGENT_LIST=""; LAZY_AGENT_LIST=""; fi

say "安装计划"
cat <<EOF
  目标挂载点 : $TARGET
  主机名     : $HOST_NAME
  主用户     : $USER_NAME
  stateVer   : $STATE_VERSION
  引导器     : $BOOTLOADER
  显卡       : $GPU_VENDOR ${NVIDIA_PCI_IDS:+(pci: $NVIDIA_PCI_IDS)}
  电池/背光  : $BATTERY / $BACKLIGHT
  Windows 项 : $WINDOWS_ENTRY
  额外会话   : ${SESSIONS:-（无）}
  预装 agent : ${AGENT_LIST:-（无，全部懒加载）}
  懒加载     : ${LAZY_AGENT_LIST:-（无）}
  软件源     : $MIRROR
  nixpkgs    : ${NIXPKGS_LOCAL:-网络（flake.lock）}
  agent 层   : $AGENT_ENABLE
EOF

if [ "$DRY_RUN" -eq 0 ]; then
  mountpoint -q "$TARGET" || die "$TARGET 未挂载；本脚本不分区，请先挂载目标根分区"
  if [ "$ASSUME_YES" -ne 1 ]; then
    printf '\n继续？会写入 %s [y/N] ' "$TARGET"
    read -r ans
    [ "$ans" = y ] || [ "$ans" = Y ] || die "已取消"
  fi
fi

say "准备工作副本（flake 用 path: 求值，避免 git 过滤掉未提交的 host）"
work="$(mktemp -d)"
cp -a "$here/." "$work/src"
rm -rf "$work/src/.git" "$work/src/result"
mkdir -p "$work/src/hosts/$HOST_NAME"

say "生成 hardware-configuration.nix"
if [ "$DRY_RUN" -eq 1 ]; then
  if [ -f "$TARGET/etc/nixos/hardware-configuration.nix" ]; then
    cp "$TARGET/etc/nixos/hardware-configuration.nix" "$work/src/hosts/$HOST_NAME/hardware-configuration.nix"
  elif [ -f "$here/hosts/$HOST_NAME/hardware-configuration.nix" ]; then
    cp "$here/hosts/$HOST_NAME/hardware-configuration.nix" "$work/src/hosts/$HOST_NAME/hardware-configuration.nix"
  else
    die "dry-run 需要现成的 hardware-configuration.nix（放在 $TARGET/etc/nixos 或 hosts/$HOST_NAME）"
  fi
else
  nixos-generate-config --root "$TARGET" --show-hardware-config \
    > "$work/src/hosts/$HOST_NAME/hardware-configuration.nix"
fi

if [ -n "$NIXPKGS_LOCAL" ]; then
  say "使用 ISO 内置 nixpkgs（离线解析 flake 输入）"
  cp "$work/src/flake.lock" "$work/flake.lock.orig"
  ( cd "$work/src" && nix flake lock --override-input nixpkgs "path:$NIXPKGS_LOCAL" >/dev/null 2>&1 )
fi

say "渲染 host 配置"
export HOSTNAME="$HOST_NAME" USERNAME="$USER_NAME" GPU_VENDOR BOOTLOADER WINDOWS_ENTRY \
       NVIDIA_PCI_IDS EXTRA_SESSIONS="$SESSIONS" BATTERY BACKLIGHT \
       AGENT_ENABLE AGENT_LIST LAZY_AGENT_LIST MIRROR STATE_VERSION
"$work/src/installer/render-host.sh" "$work/src/hosts/$HOST_NAME/default.nix"

say "求值（先确认配置可构建，再动系统）"
nix eval --raw "path:$work/src#nixosConfigurations.$HOST_NAME.config.system.build.toplevel.drvPath" > /dev/null
echo "  求值通过"

if [ "$DRY_RUN" -eq 1 ]; then
  say "dry-run 结束，未写入目标盘"
  echo "  渲染结果: $work/src/hosts/$HOST_NAME/default.nix"
  exit 0
fi

say "安装 NixOS（nixos-install --flake）"
nixos-install --flake "path:$work/src#$HOST_NAME" --root "$TARGET" --no-root-passwd

if [ -f "$work/flake.lock.orig" ]; then
  cp "$work/flake.lock.orig" "$work/src/flake.lock"
  say "已恢复 flake.lock（目标系统仍用默认源，版本与 ISO 内一致）"
fi

say "把仓库放进新系统，便于日后重建"
mkdir -p "$TARGET/home/$USER_NAME"
cp -a "$work/src" "$TARGET/home/$USER_NAME/hyprbuddy-os"
nixos-enter --root "$TARGET" -c "chown -R $USER_NAME:users /home/$USER_NAME/hyprbuddy-os"

say "完成"
cat <<EOF
下一步：
  1. 设置用户密码：  nixos-enter --root $TARGET -c "passwd $USER_NAME"
  2. 重启进入系统
  3. 首登后部署用户级配置：
       cd ~/hyprbuddy-os && ./install.sh
  4. 日常重建：
       sudo nixos-rebuild switch --flake ~/hyprbuddy-os#$HOST_NAME
EOF
