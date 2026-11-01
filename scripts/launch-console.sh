#!/usr/bin/env bash
# ============================================================
# AINBW 控制台 —— 桌面“AINBW 控制台”快捷方式的启动目标
#
# 启动 Go Core + Vite Web，然后在浏览器打开工作台。
# Ctrl+C 只停止本次启动的服务；已在运行的服务会复用。
#
# 用法：
#   ./launch-console.sh              # 启动内核 + Web 并打开浏览器
#   ./launch-console.sh --no-browser # 只启动服务，不开浏览器（自测用）
#   ./launch-console.sh --check      # 仅做环境自检，不启动
# ============================================================
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=launch-lib.sh
source "$SCRIPT_DIR/launch-lib.sh"

trap ainbw_cleanup EXIT
trap 'ainbw_cleanup; exit 0' INT TERM HUP

OPEN_BROWSER=1
for arg in "$@"; do
  case "$arg" in
    --check) CHECK_ONLY=1 ;;
    --no-browser) OPEN_BROWSER=0 ;;
    -h | --help)
      sed -n '2,15p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      echo "[错误] 未知参数：$arg（可用：--check / --no-browser）" >&2
      exit 2
      ;;
  esac
done

if [[ "${CHECK_ONLY:-0}" == "1" ]]; then
  ainbw_print_status
  exit 0
fi

echo "AINBW —— AI 原生业务工作台"
ainbw_check_web_deps || {
  ainbw_notify "AINBW 启动失败" "前端依赖未安装，请在项目根执行 npm install" critical
  exit 1
}
ainbw_start_core || {
  ainbw_notify "AINBW 启动失败" "Go Core 启动失败，详见 .local/logs/core.log" critical
  exit 1
}
ainbw_start_web || {
  ainbw_notify "AINBW 启动失败" "Web 启动失败，详见 .local/logs/web.log" critical
  exit 1
}

if [[ "$OPEN_BROWSER" == "1" ]]; then
  if command -v xdg-open >/dev/null 2>&1; then
    xdg-open "$AINBW_WEB_URL/" >/dev/null 2>&1 &
  elif command -v gio >/dev/null 2>&1; then
    gio open "$AINBW_WEB_URL/" >/dev/null 2>&1 &
  else
    echo "[提示] 未找到 xdg-open，请手动打开：$AINBW_WEB_URL/"
  fi
fi

if ((${#AINBW_STARTED[@]} == 0)); then
  echo "[就绪] 服务原本就在运行，浏览器地址：$AINBW_WEB_URL/"
  trap - EXIT
  exit 0
fi

echo "[就绪] 工作台：$AINBW_WEB_URL/"
echo "[提示] Ctrl+C 停止本次启动的 Core / Web。日志目录：$AINBW_LOG_DIR"
tail -n 0 -F "$AINBW_CORE_LOG" "$AINBW_WEB_LOG"
