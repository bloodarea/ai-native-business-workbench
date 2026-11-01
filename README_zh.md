# AI Native Business Workbench (AINBW)

**v0.2.0 · 第一个完整工程结构基线**

这是从 Electron HTML 原型 v0.1.10 扩展的真正多目录项目。包含 **Go 微内核 / React + Vite / Electron / 官方 SDK / UI 组件 / Contracts / 全栈业务插件预留 / 文档 / 自动化测试**。

> 当前只宣称真正完成的功能：Go HTTP、健康检查、静态插件发现、公开能力注册表、JSON 项目树持久化、React 宿主与保留的 v0.1.10 UI。**尚未实现完整 SQLite、运行态插件、业务数据流或安装包。**

## 启动
环境：Go 1.23+，Node.js 20+，npm，联网安装 npm 依赖。

```bash
npm install
npm run dev
```

会先启动 `http://127.0.0.1:4177` 的 Go Core，然后启动 Vite，再启动 Electron。

只启动后台无需 Node：

```bash
go run ./cmd/ainbw-core
```

独立 Web：一个终端运行 Go Core；另一个终端运行 `npm run dev:web`，打开 `http://127.0.0.1:5273`。

开发者中心（初始能力注册表演示）：`http://127.0.0.1:5273/#/developer`。

Web 端口默认 5273（避开 Vite 常用的 5173），可用 `AINBW_WEB_PORT` 覆盖。

```bash
go test ./...
npm run build:web
npm run build:core
# 构建后由 Go 直接托管 React 静态网页：
go run ./cmd/ainbw-core --web-dir apps/web/dist
```

## 项目结构

```text
AI_Native_Workbench_v0.2.0/
├── apps/
│   ├── desktop/                  # Electron 独立桌面窗口
│   └── web/                      # React + TypeScript + Vite + legacy Shell
├── cmd/ainbw-core/               # Go 微内核启动入口
├── internal/
│   ├── domain/                   # 领域核心与治理语义预留
│   ├── platform/                 # 存储、插件、权限、任务、事件、审计等
│   └── transport/httpapi/        # HTTP 传输接口
├── packages/
│   ├── contracts/                # OpenAPI / Schema / Plugin Manifest
│   ├── sdk/                      # 官方 TypeScript SDK 起步版
│   └── ui/                       # React 公共组件及设计 token 预留
├── plugins/
│   ├── software-development/     # 软件研发内置业务插件骨架
│   ├── content-creation/         # 自媒体运营预留
│   ├── smart-manufacturing/      # 智能制造预留
│   └── 3d-workspace/             # Three.js/Blender SDK 适配预留
├── docs/                         # 架构、开发、开发者中心、安全、测试
├── scripts/                      # 跨平台开发启动与检查脚本
├── .github/workflows/            # Go/Web CI
└── AGENTS.md                     # 简短工程纪律
```

## 视觉一致性与迁移说明

为确保已确认的 v0.1.10 **外观与项目/菜单/设置交互不会丢失**，`apps/web/public/shell/index.html` 暂时保留了原单 HTML 实现，并由 React 宿主 iframe 展示。此方法是 **过渡层**，不代表旧页面已经重写成 React 组件。正式组件迁移应先以 `packages/ui` 规范为准，逐个迁移并通过截图回归测试。

旧页面原有项目树仍使用 localStorage 作为快速副本；Go Core 在线时同步到 `.local/data/project-tree.json`。同步当前为 best-effort，没有冲突处理，不应该当成多端可靠数据同步。

## 参考
- [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness)：借鉴工程分层、插件化和自动测试组织方式，**未复制其源代码、未引入 Cordis**。
- `docs/architecture/overview.md`、`docs/development/roadmap.md`：具体设计裁定与真实开发状态。

## 工程注意
- `npm install` 首次需要访问 npm registry；ZIP 不包含 node_modules，也不是已打包的 .exe。
- Go 不依赖第三方模块，能够离线编译并运行；当前默认 JSON 持久化，SQLite 预留。
- Electron 的生产 Go 服务守护和安装包构建尚未实现；不要直接对外发布为生产软件。
