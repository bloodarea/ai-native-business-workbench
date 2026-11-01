#!/usr/bin/env bash
# ============================================================
# AINBW —— 桌面快捷方式共用启动库
#
# 被 launch-console.sh / launch-desktop.sh source，不单独执行。
# 调用方负责 trap 清理；本库用 AINBW_STARTED 记录“本次启动”的进程，
# 已在运行的服务只复用，不接管、不停止。
# ============================================================
# shellcheck shell=bash

AINBW_REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AINBW_LOG_DIR="$AINBW_REPO_ROOT/.local/logs"
AINBW_DATA_DIR="$AINBW_REPO_ROOT/.local/data"
AINBW_BIN="$AINBW_REPO_ROOT/bin/ainbw-core"
AINBW_ELECTRON="$AINBW_REPO_ROOT/node_modules/electron/dist/electron"
# 端口只在这一处推导，vite.config.ts、Electron 主进程与 dev.mjs 读同一组环境变量。
# Web 默认 5273 而非 Vite 的 5173：5173 极易被同机其他 Vite 项目占用（strictPort 会直接启动失败）。
AINBW_CORE_PORT="${AINBW_CORE_PORT:-4177}"
AINBW_WEB_PORT="${AINBW_WEB_PORT:-5273}"
AINBW_CORE_URL="http://127.0.0.1:$AINBW_CORE_PORT"
AINBW_WEB_URL="http://127.0.0.1:$AINBW_WEB_PORT"
export AINBW_CORE_URL AINBW_WEB_PORT
AINBW_CORE_LOG="$AINBW_LOG_DIR/core.log"
AINBW_WEB_LOG="$AINBW_LOG_DIR/web.log"
AINBW_STARTED=()

# 桌面快捷方式不加载交互式 shell 的 PATH，补齐本机用户级工具链。
export PATH="$HOME/.local/toolchain/go/bin:$HOME/.local/share/node/bin:$HOME/.local/bin:$PATH"
# 桌面会话若预设这两个变量，前者会把 Electron 退化成纯 Node 运行时
# （require('electron') 返回 undefined），后者会污染子进程 —— 启动前一律清掉。
unset ELECTRON_RUN_AS_NODE NODE_OPTIONS
# 首次 npm install 时 Electron 二进制走国内镜像（已安装时无副作用）。
export ELECTRON_MIRROR="${ELECTRON_MIRROR:-https://npmmirror.com/mirrors/electron/}"

mkdir -p "$AINBW_LOG_DIR" "$AINBW_DATA_DIR" "$AINBW_REPO_ROOT/bin"

ainbw_notify() {
  local title="$1" body="${2:-}" urgency="${3:-normal}"
  command -v notify-send >/dev/null 2>&1 || return 0
  notify-send -a AINBW -u "$urgency" "$title" "$body" 2>/dev/null || true
}

ainbw_log_tail() {
  tail -n "${2:-8}" "$1" 2>/dev/null || true
}

ainbw_http_ok() { curl -fsS --max-time 2 "$1" >/dev/null 2>&1; }

ainbw_core_ok() { ainbw_http_ok "$AINBW_CORE_URL/api/v1/health"; }

ainbw_web_ok() {
  local body
  body="$(curl -fsS --max-time 2 "$AINBW_WEB_URL/" 2>/dev/null)" || return 1
  [[ "$body" == *"AI原生业务工作台"* || "$body" == *"AI Native Business Workbench"* ]]
}

# 端口有监听但服务不认识时（别的程序占着），直接报错而不是叠一个必然失败的服务。
ainbw_port_busy() {
  local port="$1"
  (exec 3<>"/dev/tcp/127.0.0.1/$port") >/dev/null 2>&1
}

ainbw_wait_for() {
  local desc="$1" check="$2" pid="${3:-}" timeout="${4:-30}" i
  for ((i = 0; i < timeout * 5; i++)); do
    if "$check"; then return 0; fi
    if [[ -n "$pid" ]] && ! kill -0 "$pid" 2>/dev/null; then
      echo "[错误] $desc 进程已退出" >&2
      return 1
    fi
    sleep 0.2
  done
  echo "[错误] 等待 $desc 超时（${timeout}s）" >&2
  return 1
}

ainbw_check_web_deps() {
  command -v node >/dev/null 2>&1 || { echo "[错误] 未找到 Node.js（需要 20+）" >&2; return 1; }
  command -v npm >/dev/null 2>&1 || { echo "[错误] 未找到 npm" >&2; return 1; }
  if [[ ! -x "$AINBW_REPO_ROOT/node_modules/.bin/vite" ]]; then
    echo "[错误] 前端依赖未安装。请在项目根执行：" >&2
    echo "       ELECTRON_MIRROR=$ELECTRON_MIRROR npm install" >&2
    return 1
  fi
}

ainbw_check_electron() {
  if [[ ! -x "$AINBW_ELECTRON" ]]; then
    echo "[错误] 未找到 Electron：$AINBW_ELECTRON" >&2
    echo "       请在项目根执行：ELECTRON_MIRROR=$ELECTRON_MIRROR npm install" >&2
    return 1
  fi
}

# 递归停止进程树（npm → sh → vite 是多层子进程）。
ainbw_kill_tree() {
  local pid="$1" child
  for child in $(pgrep -P "$pid" 2>/dev/null); do
    ainbw_kill_tree "$child"
  done
  kill -TERM "$pid" 2>/dev/null || true
}

ainbw_cleanup() {
  local entry kind pid
  for entry in "${AINBW_STARTED[@]:-}"; do
    [[ -n "$entry" ]] || continue
    kind="${entry%% *}"
    pid="${entry##* }"
    echo "[收尾] 停止本次启动的 $kind (pid $pid)" >&2
    ainbw_kill_tree "$pid"
  done
  AINBW_STARTED=()
  sleep 0.4
}

ainbw_build_core() {
  local newer
  if [[ -x "$AINBW_BIN" ]]; then
    newer="$(find "$AINBW_REPO_ROOT" \
      \( -path "$AINBW_REPO_ROOT/node_modules" \
      -o -path "$AINBW_REPO_ROOT/.git" \
      -o -path "$AINBW_REPO_ROOT/.local" \) -prune \
      -o -name '*.go' -newer "$AINBW_BIN" -print -quit 2>/dev/null)"
    [[ -z "$newer" ]] && return 0
  fi
  command -v go >/dev/null 2>&1 || { echo "[错误] 未找到 Go（需要 1.23+，内核构建依赖）" >&2; return 1; }
  echo "[启动] 构建 Go Core ..."
  if ! (cd "$AINBW_REPO_ROOT" && go build -o "$AINBW_BIN.tmp" ./cmd/ainbw-core) \
    >>"$AINBW_LOG_DIR/build.log" 2>&1; then
    echo "[错误] Go Core 构建失败，日志：$AINBW_LOG_DIR/build.log" >&2
    ainbw_log_tail "$AINBW_LOG_DIR/build.log" 15 >&2
    return 1
  fi
  mv -f "$AINBW_BIN.tmp" "$AINBW_BIN"
}

ainbw_start_core() {
  if ainbw_core_ok; then
    echo "[就绪] Go Core 已在运行：$AINBW_CORE_URL"
    return 0
  fi
  if ainbw_port_busy "$AINBW_CORE_PORT"; then
    echo "[错误] 端口 $AINBW_CORE_PORT 已被其他进程占用，且不是 AINBW Core（/api/v1/health 不可用）" >&2
    return 1
  fi
  ainbw_build_core || return 1
  echo "[启动] Go Core → $AINBW_CORE_URL"
  (cd "$AINBW_REPO_ROOT" && exec "$AINBW_BIN" \
    --addr "127.0.0.1:$AINBW_CORE_PORT" \
    --data-dir "$AINBW_DATA_DIR" \
    --plugins-dir plugins) >>"$AINBW_CORE_LOG" 2>&1 </dev/null &
  local pid=$!
  AINBW_STARTED+=("core $pid")
  if ! ainbw_wait_for "Go Core" ainbw_core_ok "$pid" 20; then
    ainbw_log_tail "$AINBW_CORE_LOG" 20 >&2
    return 1
  fi
  echo "[就绪] Go Core 已启动"
}

ainbw_start_web() {
  if ainbw_web_ok; then
    echo "[就绪] Web 已在运行：$AINBW_WEB_URL"
    return 0
  fi
  if ainbw_port_busy "$AINBW_WEB_PORT"; then
    echo "[错误] 端口 $AINBW_WEB_PORT 已被其他进程占用，且不是 AINBW Web（页面标题不匹配）" >&2
    return 1
  fi
  ainbw_check_web_deps || return 1
  echo "[启动] Web (Vite) → $AINBW_WEB_URL"
  (cd "$AINBW_REPO_ROOT" && exec npm run dev:web) >>"$AINBW_WEB_LOG" 2>&1 </dev/null &
  local pid=$!
  AINBW_STARTED+=("web $pid")
  if ! ainbw_wait_for "Web (Vite)" ainbw_web_ok "$pid" 40; then
    ainbw_log_tail "$AINBW_WEB_LOG" 20 >&2
    return 1
  fi
  echo "[就绪] Web 已启动"
}

ainbw_print_status() {
  echo "AINBW 启动环境自检"
  echo "  项目根目录 : $AINBW_REPO_ROOT"
  printf '  Go         : '
  if command -v go >/dev/null 2>&1; then go version; else echo '缺失'; fi
  printf '  Node       : '
  if command -v node >/dev/null 2>&1; then node -v; else echo '缺失'; fi
  printf '  npm        : '
  if command -v npm >/dev/null 2>&1; then npm -v; else echo '缺失'; fi
  printf '  前端依赖   : '
  if [[ -x "$AINBW_REPO_ROOT/node_modules/.bin/vite" ]]; then echo '已安装'; else echo '未安装（npm install）'; fi
  printf '  Electron   : '
  if [[ -x "$AINBW_ELECTRON" ]]; then
    node -p "require('$AINBW_REPO_ROOT/node_modules/electron/package.json').version" 2>/dev/null || echo '已安装'
  else
    echo '未安装（npm install）'
  fi
  printf '  Go Core    : '
  if ainbw_core_ok; then echo "运行中（$AINBW_CORE_URL）"; else echo '未运行'; fi
  printf '  Web        : '
  if ainbw_web_ok; then echo "运行中（$AINBW_WEB_URL）"; else echo '未运行'; fi
}
