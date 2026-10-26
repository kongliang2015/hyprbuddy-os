# 跨选项一致性检查：越早报错越好，避免装出一个"看起来正常"的错误系统。
{ config, lib, ... }:
let
  cfg = config.distro;
in
{
  assertions = [
    {
      assertion = cfg.desktop.enable || cfg.desktop.extraSessions == [ ];
      message = "distro.desktop.enable = false 时不能指定 distro.desktop.extraSessions。";
    }
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
  ];
}
