# agent 层：崩溃诊断。监听 coredump 目录，用本地模型分析最近一次崩溃。
{ config, lib, pkgs, ... }:
let
  cfg = config.distro.agent;
  user = config.distro.user.name;
  userHome = config.users.users.${user}.home;

  analyze = pkgs.writeShellScript "coredump-analyze" ''
    set -euo pipefail
    state_dir="''${HOME}/.local/state/agent"
    mkdir -p "$state_dir"

    info=$(${pkgs.systemd}/bin/coredumpctl info --no-pager -1 2>/dev/null || true)
    if [ -z "$info" ]; then
      exit 0
    fi

    payload=$(${pkgs.jq}/bin/jq -n \
      --arg m ${lib.escapeShellArg cfg.model} \
      --arg p "请分析下面这条 Linux core dump，给出崩溃原因与可执行的修复建议，控制在 300 字内：
$info" \
      '{model: $m, prompt: $p, stream: false}')

    resp=$(${pkgs.curl}/bin/curl -sS --max-time 180 \
      -H 'Content-Type: application/json' -d "$payload" \
      http://127.0.0.1:11434/api/generate 2>/dev/null \
      | ${pkgs.jq}/bin/jq -r '.response // empty' 2>/dev/null || true)

    if [ -z "$resp" ]; then
      exit 0
    fi

    report="$state_dir/coredump-report.md"
    {
      printf '# coredump 诊断 %s

' "$(date -Is)"
      coredumpctl info --no-pager -1 2>/dev/null | head -40 || true
      printf '
## 分析

%s
' "$resp"
    } > "$report"

    ${pkgs.libnotify}/bin/notify-send -a agent-diagnostics "崩溃诊断" \
      "$(printf '%s' "$resp" | head -c 200)" 2>/dev/null || true
  '';
in
lib.mkIf (cfg.enable && cfg.diagnostics) {
  # 只读监听：coredump 写入即触发一次分析
  systemd.paths.coredump-watch = {
    wantedBy = [ "multi-user.target" ];
    pathConfig.PathChanged = "/var/lib/systemd/coredump";
  };

  systemd.services.coredump-analyze = {
    description = "Analyze newest core dump with local LLM";
    wants = lib.optional cfg.localModels "ollama.service";
    after = lib.optional cfg.localModels "ollama.service";
    serviceConfig = {
      Type = "oneshot";
      User = user;
      # coredump 文件属于 systemd-coredump 组，读权限由此获得
      SupplementaryGroups = [ "systemd-coredump" ];
      ExecStart = "${analyze}";
      Environment = [ "HOME=${userHome}" ];
    };
  };

  assertions = [
    {
      assertion = cfg.localModels;
      message = "distro.agent.diagnostics 依赖本地模型（distro.agent.localModels = true），诊断不会上传 core dump。";
    }
  ];
}
