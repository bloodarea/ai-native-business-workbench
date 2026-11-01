import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import path from 'node:path';
// 端口只在这里推导：scripts/dev.mjs、Electron 主进程与 launch-lib.sh 都读同一个
// AINBW_WEB_PORT，避免多处硬编码各自漂移。默认 5273 而非 Vite 默认的 5173——
// 5173 极易被同机其他 Vite 项目抢占（strictPort 会直接启动失败）。
const webPort = Number(process.env.AINBW_WEB_PORT ?? 5273);
const coreOrigin = process.env.AINBW_CORE_URL ?? 'http://127.0.0.1:4177';
export default defineConfig({
  plugins: [react()],
  server: {
    port: webPort,
    strictPort: true,
    fs: { allow: [path.resolve(__dirname, '../..')] },
    proxy: { '/api': { target: coreOrigin, changeOrigin: true } },
  },
});
