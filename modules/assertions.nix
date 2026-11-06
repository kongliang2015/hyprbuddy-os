# 跨选项一致性检查：越早报错越好，避免装出一个"看起来正常"的错误系统。
{ config, lib, ... }:
let
  cfg = config.distro;
in
{
  assertions = [
    {
      assertion = cfg.gpu.vendor != "none" || !cfg.desktop.enable;
      message = "distro.gpu.vendor = \"none\"（headless）时请同时设置 distro.desktop.enable = false。";
    }
    {
      assertion = builtins.elem cfg.desktop.default cfg.desktop.sessions;
      message = "distro.desktop.default 必须是 distro.desktop.sessions 中的一项。";
    }
    {
      assertion = cfg.agent.enable || !cfg.agent.localModels;
      message = "distro.agent.localModels 需要 distro.agent.enable = true。";
    }
    {
      assertion = builtins.all (a: !(builtins.elem a cfg.agent.agents)) cfg.agent.lazyAgents;
      message = "distro.agent.lazyAgents 与 distro.agent.agents 不能有交集（同一 agent 只能预装或懒加载其一）。";
    }
  ];
}
