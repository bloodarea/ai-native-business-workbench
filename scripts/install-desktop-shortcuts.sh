#!/usr/bin/env bash
# ============================================================
# AINBW —— 安装/重建桌面快捷方式
#
# 生成两个 .desktop 条目（与 SpiderDeck 一致的双入口）：
#   AINBW 控制台  → scripts/launch-console.sh（内核 + Web + 浏览器，终端里跑）
#   AINBW Desktop → scripts/launch-desktop.sh（内核 + Web + Electron 客户端）
#
# 同时写入 ~/桌面 与 ~/.local/share/applications，并标记 trusted。
# 项目移动位置后重新执行一次即可。
# ============================================================
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ELECTRON_MIRROR="${ELECTRON_MIRROR:-https://npmmirror.com/mirrors/electron/}"
EXEC_CONSOLE="$REPO_ROOT/scripts/launch-console.sh"
EXEC_DESKTOP="$REPO_ROOT/scripts/launch-desktop.sh"
APPS_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
DESKTOP_DIR="$(xdg-user-dir DESKTOP 2>/dev/null || true)"
[[ -n "$DESKTOP_DIR" && -d "$DESKTOP_DIR" ]] || DESKTOP_DIR="$HOME/Desktop"

[[ -x "$EXEC_CONSOLE" ]] || { echo "[错误] 缺少启动脚本：$EXEC_CONSOLE" >&2; exit 1; }
[[ -x "$EXEC_DESKTOP" ]] || { echo "[错误] 缺少启动脚本：$EXEC_DESKTOP" >&2; exit 1; }
mkdir -p "$APPS_DIR" "$DESKTOP_DIR"

write_desktop() {
  local filename="$1" body="$2" dir target
  for dir in "$APPS_DIR" "$DESKTOP_DIR"; do
    target="$dir/$filename"
    printf '%s\n' "$body" >"$target"
    chmod +x "$target"
    # Ubuntu 24.04 的桌面图标默认不可执行，需标记 trusted 才能双击启动。
    gio set "$target" metadata::trusted true 2>/dev/null || true
    echo "已写入：$target"
  done
  if command -v desktop-file-validate >/dev/null 2>&1; then
    desktop-file-validate "$APPS_DIR/$filename" || true
  fi
}

write_desktop "ainbw-desktop.desktop" "[Desktop Entry]
Version=1.0
Type=Application
Name=AINBW Desktop
Name[zh_CN]=AINBW 桌面客户端
Comment=AI Native Business Workbench desktop client (Go Core + Vite + Electron)
Comment[zh_CN]=AI 原生业务工作台桌面客户端（Go 内核 + Vite + Electron）
Exec=$EXEC_DESKTOP
Path=$REPO_ROOT
Icon=applications-internet
Terminal=false
Categories=Development;
StartupNotify=true
StartupWMClass=@ainbw/desktop"

write_desktop "ainbw-console.desktop" "[Desktop Entry]
Version=1.0
Type=Application
Name=AINBW Console
Name[zh_CN]=AINBW 控制台
Comment=AINBW launcher (Go Core + Web, opens browser)
Comment[zh_CN]=AINBW 启动器（Go 内核 + Web，自动打开浏览器）
Exec=$EXEC_CONSOLE
Path=$REPO_ROOT
Icon=utilities-terminal
Terminal=true
Categories=Development;
StartupNotify=false"

if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database "$APPS_DIR" >/dev/null 2>&1 || true
fi

echo
echo "完成。桌面上的「AINBW 桌面客户端」和「AINBW 控制台」可直接双击。"
echo "提示：首次运行需先安装依赖：cd \"$REPO_ROOT\" && ELECTRON_MIRROR=$ELECTRON_MIRROR npm install"
