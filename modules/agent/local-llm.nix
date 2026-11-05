# agent 层：本地模型。默认 CPU 变体，GPU 加速需显式开启。
{ config, lib, pkgs, ... }:
let
  cfg = config.distro.agent;
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
    host = "127.0.0.1";
  };
}
