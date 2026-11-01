# AI Native Business Workbench · v0.2.0

Complete source tree baseline: Electron desktop / React+TS+Vite / Go Core / plugins / SDK / UI / contracts / tests.

**Requirements:** Go 1.23+, Node.js 20+, npm. `npm install && npm run dev` starts Go Core, Web Vite and Electron. For Go-only: `go run ./cmd/ainbw-core`, then query `http://127.0.0.1:4177/api/v1/health`.

**Important scope:** The Go HTTP APIs, manifest discovery, capability registry and atomic JSON project-tree persistence are real. Full plugin execution, SQLite, auth, domain-specific business workflows and packaged installers remain placeholders. The existing v0.1.10 shell is hosted unchanged (with a small API bridge) in `apps/web/public/shell/`, using a React compatibility iframe until component migration.

See [Chinese documentation](README_zh.md) and [implementation roadmap](docs/development/roadmap.md).
