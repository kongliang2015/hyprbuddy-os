# agent 层汇总。六层能力对应六个文件/脚本：
#   入口 core.nix / 主题 scripts/agent-theme-sync / 诊断 diagnostics.nix
#   观测 usage.nix / 变更 scripts/agent-apply / 本地模型 local-llm.nix
{ ... }:
{
  imports = [
    ./core.nix
    ./diagnostics.nix
    ./local-llm.nix
  ];
}
