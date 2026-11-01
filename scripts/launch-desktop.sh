#!/usr/bin/env bash
# ============================================================
# AINBW 桌面客户端 —— 桌面“AINBW Desktop”快捷方式的启动目标
#
# 确保 Go Core + Vite Web 已就绪，然后启动 Electron 源码壳。
# Electron 退出后只停止本次启动的 Core / Web；复用中的服务不动。
# 失败时用桌面通知反馈（.desktop 的 Terminal=false，看不到终端输出）。
# ============================================================
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=launch-lib.sh
source "$SCRIPT_DIR/launch-lib.sh"

trap ainbw_cleanup EXIT
trap 'ainbw_cleanup; exit 0' INT TERM HUP

fail() {
  local message="$1"
  echo "$message" >&2
  ainbw_notify "AINBW 启动失败" "$message" critical
  exit 1
}

if [[ -z "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]]; then
  fail "没有可用的图形会话（DISPLAY / WAYLAND_DISPLAY 均为空）"
fi

ainbw_check_web_deps || fail "前端依赖未安装，请在项目根执行 npm install"
ainbw_check_electron || fail "Electron 未安装，请在项目根执行 npm install"

ainbw_start_core || fail "Go Core 启动失败，详见 .local/logs/core.log"
ainbw_start_web || fail "Web 启动失败，详见 .local/logs/web.log"

# Linux 沙箱自检：chrome-sandbox 必须是 root 属主 + 4755（SUID）。
# npm 装出来的是用户属主；本机 apparmor_restrict_unprivileged_userns=1，
# userns 备用路径被封死，Chromium 沙箱初始化会直接 FATAL。
# 修不了就退 --no-sandbox 保证双击可用；SUID 修好后自动恢复真沙箱。
SANDBOX_ARGS=()
SANDBOX_HELPER="$AINBW_REPO_ROOT/node_modules/electron/dist/chrome-sandbox"
if [[ -f "$SANDBOX_HELPER" ]] && {
  [[ ! -u "$SANDBOX_HELPER" ]] ||
    [[ "$(stat -c %U "$SANDBOX_HELPER" 2>/dev/null)" != "root" ]]
}; then
  SANDBOX_ARGS=(--no-sandbox)
  # 不弹桌面通知：每次启动都提示会打断使用；只写日志，必要时排查。
  echo "[提示] chrome-sandbox 未配置 SUID，本次以 --no-sandbox 兼容模式启动" >>"$AINBW_LOG_DIR/desktop.log"
  echo "[提示] 要启用完整沙箱：sudo chown root:root '$SANDBOX_HELPER' && sudo chmod 4755 '$SANDBOX_HELPER'" >>"$AINBW_LOG_DIR/desktop.log"
fi

echo "[启动] Electron 客户端 → $AINBW_WEB_URL"
cd "$AINBW_REPO_ROOT" || fail "无法进入项目根目录：$AINBW_REPO_ROOT"

# Chromium/Electron 在 Linux 会读取代理环境变量。本机的 ALL_PROXY=socks://…
# 会让 Electron 的 network service 在启动时崩溃、页面永远加载不出来
# （窗口已创建但一直 hidden）。桌面壳只访问 127.0.0.1，清掉代理走直连。
unset HTTP_PROXY HTTPS_PROXY http_proxy https_proxy ALL_PROXY all_proxy NODE_USE_ENV_PROXY

if ! "$AINBW_ELECTRON" "${SANDBOX_ARGS[@]}" "$AINBW_REPO_ROOT/apps/desktop" \
  >>"$AINBW_LOG_DIR/desktop.log" 2>&1; then
  message="$(ainbw_log_tail "$AINBW_LOG_DIR/desktop.log" 12)"
  echo "$message" >&2
  ainbw_notify "AINBW 启动失败" "$message" critical
  exit 1
fi
