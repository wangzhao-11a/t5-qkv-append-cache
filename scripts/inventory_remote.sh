#!/usr/bin/env bash
set -u
inspect() {
  if command -v "$1" >/dev/null 2>&1; then "$@"; else printf 'unavailable command: %s\n' "$1"; fi
}
printf '%s\n' '=== host and OS ==='
inspect cat /proc/sys/kernel/hostname
inspect uname -m
inspect cat /etc/os-release
printf '%s\n' '=== device inventory ==='
if command -v npu-smi >/dev/null; then npu-smi info; else printf '%s\n' 'npu-smi not on PATH'; fi
printf '%s\n' '=== ports ==='
inspect ss -lntp
printf '%s\n' '=== workers ==='
inspect ps -eo pid,ppid,comm,args | grep -E 'python|vllm|xllm|ais_bench|benchmark|mindie' | grep -v grep || true
printf '%s\n' '=== containers ==='
if command -v docker >/dev/null; then docker ps -a --format '{{.ID}}\t{{.Image}}\t{{.Names}}\t{{.Status}}'; fi
printf '%s\n' '=== CANN installation ==='
find /usr/local/Ascend -maxdepth 3 -type f \( -name version.info -o -name ascend_toolkit_install.info \) -print 2>/dev/null || true
printf '%s\n' '=== host Python and compiler ==='
inspect python3 --version
command -v msopgen || true
command -v bisheng || true
printf '%s\n' '=== container runtime marker ==='
test ! -f /.dockerenv || printf '%s\n' 'Current SSH target is itself a container'
