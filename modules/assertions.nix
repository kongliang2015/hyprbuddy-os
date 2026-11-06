# 跨选项一致性检查：越早报错越好，避免装出一个"看起来正常"的错误系统。
{ config, lib, ... }:
let
  cfg = config.distro;
  loopbackHosts = [ "127.0.0.1" "::1" "localhost" ];
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
    {
      assertion = cfg.agent.localEndpoint.lan || builtins.elem cfg.agent.localEndpoint.bind loopbackHosts;
      message = "distro.agent.localEndpoint.bind = \"${cfg.agent.localEndpoint.bind}\" 不是回环地址：要对外暴露请同时设 distro.agent.localEndpoint.lan = true（默认只绑 127.0.0.1）。";
    }
    {
      assertion = !cfg.agent.localEndpoint.lan || !(builtins.elem cfg.agent.localEndpoint.bind loopbackHosts);
      message = "distro.agent.localEndpoint.lan = true 但 bind 仍是回环地址，外部无法访问；请设 bind = \"0.0.0.0\" 或具体网卡地址。";
    }
    {
      assertion = !cfg.agent.localEndpoint.lan || cfg.agent.localModels;
      message = "distro.agent.localEndpoint.lan 需要 distro.agent.localModels = true（端点未启用时暴露无意义）。";
    }
  ];
}
