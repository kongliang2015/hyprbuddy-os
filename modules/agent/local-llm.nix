# agent 层：本地模型。按 GPU 厂商选择 ollama 变体，避免云端上传 core dump。
{ config, lib, pkgs, ... }:
let
  cfg = config.distro.agent;
  vendor = config.distro.gpu.vendor;

  package =
    if vendor == "nvidia" then pkgs.ollama-cuda
    else if vendor == "amd" then pkgs.ollama-rocm
    else if vendor == "intel" then pkgs.ollama-vulkan
    else pkgs.ollama-cpu;
in
lib.mkIf (cfg.enable && cfg.localModels) {
  services.ollama = {
    enable = true;
    inherit package;             # 26.05 已移除 acceleration 选项，改用包变体
    host = "127.0.0.1";
  };
}
