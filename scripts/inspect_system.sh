#!/usr/bin/env bash
set -Eeuo pipefail

section() {
  printf '\n== %s ==\n' "$1"
}

item() {
  printf ' - %s: %s\n' "$1" "$2"
}

section "System"
if [[ -f /etc/os-release ]]; then
  # shellcheck source=/dev/null
  . /etc/os-release
  item "OS" "${PRETTY_NAME:-${ID:-unknown}}"
elif command -v sw_vers >/dev/null 2>&1; then
  item "OS" "$(sw_vers -productName) $(sw_vers -productVersion) (build $(sw_vers -buildVersion))"
else
  item "OS" "unknown"
fi
item "Kernel" "$(uname -r)"
item "Hostname" "$(hostname)"

section "Software"
if command -v nvidia-smi >/dev/null 2>&1; then
  driver=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null | head -n1)
  item "NVIDIA Driver" "${driver:-detected}"
else
  item "NVIDIA Driver" "nvidia-smi not found"
fi

if command -v nvcc >/dev/null 2>&1; then
  toolkit=$(nvcc --version | grep release | sed -E 's/.*release ([^,]+).*/\1/')
  item "CUDA Toolkit" "${toolkit:-detected}"
else
  item "CUDA Toolkit" "nvcc not found"
fi

if command -v docker >/dev/null 2>&1; then
  item "Docker" "$(docker --version 2>/dev/null)"
else
  item "Docker" "docker not found"
fi

if command -v python3 >/dev/null 2>&1; then
  item "Python" "$(python3 --version 2>&1)"
else
  item "Python" "python3 not found"
fi

if command -v pip3 >/dev/null 2>&1; then
  item "pip" "$(pip3 --version 2>&1)"
else
  item "pip" "pip3 not found"
fi

if command -v python3 >/dev/null 2>&1; then
  python_code=$'import importlib\nreport = []\nfor name in ("torch", "torchvision"):\n    try:\n        module = importlib.import_module(name)\n        ver = getattr(module, "__version__", "unknown")\n        extra = ""\n        if name == "torch":\n            import torch\n            extra = f" (cuda_available={torch.cuda.is_available()})"\n        report.append(f"{name} {ver}{extra}")\n    except Exception as exc:\n        report.append(f"{name} not installed ({exc.__class__.__name__})")\nprint("; ".join(report))\n'
  set +e
  torch_report="$(python3 -c "$python_code" 2>/dev/null)"
  torch_status=$?
  set -e
  if [[ $torch_status -eq 0 && -n "$torch_report" ]]; then
    item "Torch Stack" "$torch_report"
  else
    item "Torch Stack" "torch modules not installed"
  fi

  if [[ "${INFR_DEBUG:-false}" == "true" ]]; then
    set +e
    wandb_version="$(python3 -m pip show wandb 2>/dev/null | awk -F': ' '/^Version/ {print $2; exit}')"
    wandb_status=$?
    set -e
    if [[ $wandb_status -eq 0 && -n "$wandb_version" ]]; then
      item "Weights & Biases" "Version ${wandb_version}"
    else
      item "Weights & Biases" "not installed"
    fi

    set +e
    hf_version="$(python3 -m pip show huggingface_hub 2>/dev/null | awk -F': ' '/^Version/ {print $2; exit}')"
    hf_status=$?
    set -e
    if [[ $hf_status -eq 0 && -n "$hf_version" ]]; then
      item "Hugging Face Hub" "Version ${hf_version}"
    else
      item "Hugging Face Hub" "not installed"
    fi
  else
    if python3 -m pip show wandb >/dev/null 2>&1; then
      wandb_version=$(python3 -m pip show wandb 2>/dev/null | awk -F': ' '/^Version/ {print $2; exit}')
      item "Weights & Biases" "${wandb_version:-installed}"
    else
      item "Weights & Biases" "not installed"
    fi

    if python3 -m pip show huggingface_hub >/dev/null 2>&1; then
      hf_version=$(python3 -m pip show huggingface_hub 2>/dev/null | awk -F': ' '/^Version/ {print $2; exit}')
      item "Hugging Face Hub" "${hf_version:-installed}"
    else
      item "Hugging Face Hub" "not installed"
    fi
  fi
else
  item "Torch Stack" "python3 not available"
  item "Weights & Biases" "python3 not available"
  item "Hugging Face Hub" "python3 not available"
fi

section "Hardware"
if command -v lscpu >/dev/null 2>&1; then
  cpu_model=$(lscpu | awk -F': ' '/Model name/ {print $2; exit}')
else
  cpu_model=$(awk -F': ' '/model name/ {print $2; exit}' /proc/cpuinfo 2>/dev/null || echo "unknown")
fi
item "CPU Model" "${cpu_model:-unknown}"
item "CPU Cores" "$(nproc 2>/dev/null || echo "unknown")"

if command -v nvidia-smi >/dev/null 2>&1; then
  gpu_info=$(nvidia-smi --query-gpu=name,memory.total --format=csv,noheader 2>/dev/null | head -n1)
  item "GPU" "${gpu_info:-detected}"
else
  item "GPU" "not detected"
fi

if command -v free >/dev/null 2>&1; then
  ram=$(free -h | awk '/^Mem:/ {print $2 " total, " $3 " used"}')
  item "Memory" "$ram"
else
  item "Memory" "free command not available"
fi

if command -v df >/dev/null 2>&1; then
  disk=$(df -h / | awk 'NR==2 {print $2 " total, " $3 " used, " $4 " free"}')
  item "Disk (/)" "$disk"
else
  item "Disk (/)" "df command not available"
fi

section "Summary"
item "Timestamp" "$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
