# agent 层：本地模型。默认 CPU 变体，GPU 加速需显式开启。
{ config, lib, pkgs, ... }:
let
  cfg = config.distro.agent;
  ep = cfg.localEndpoint;
  vendor = config.distro.gpu.vendor;

  gpuPackage =
    if vendor == "nvidia" then pkgs.ollama-cuda
    else if vendor == "amd" then pkgs.ollama-rocm
    else if vendor == "intel" then pkgs.ollama-vulkan
    else pkgs.ollama-cpu;
  # 默认走 CPU，避免 CUDA/ROCm 工具链成为系统 closure 的硬性依赖。
  package = if cfg.ollamaAcceleration == "gpu" then gpuPackage else pkgs.ollama-cpu;
in
lib.mkIf (cfg.enable && cfg.localModels) {
  services.ollama = {
    enable = true;
    inherit package;             # 26.05 已移除 acceleration 选项，改用包变体
    host = ep.bind;              # 默认 127.0.0.1；非回环地址由断言配合 lan 开关兜住
    # 并发上限固定成显式值：ollama 会按硬件自行放大并发，小内存机器上容易挤爆 RAM。
    environmentVariables.OLLAMA_NUM_PARALLEL = toString ep.maxConcurrent;
    openFirewall = ep.lan;
  };
}
