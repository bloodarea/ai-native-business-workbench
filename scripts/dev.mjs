import { spawn } from 'node:child_process';
import { setTimeout as sleep } from 'node:timers/promises';
// 与 vite.config.ts / Electron 主进程共用同一组环境变量：换端口只改环境变量，不碰代码。
const WEB_PORT = Number(process.env.AINBW_WEB_PORT ?? 5273);
const CORE_PORT = Number(process.env.AINBW_CORE_PORT ?? 4177);
const WEB_URL = `http://127.0.0.1:${WEB_PORT}`;
const CORE_URL = `http://127.0.0.1:${CORE_PORT}`;
const children=[];
let stopping=false;
function launch(label, cmd, args, env={}){
 const p=spawn(cmd,args,{stdio:'inherit',env:{...process.env,...env},shell:process.platform==='win32'});
 children.push(p);p.on('exit',code=>{if(!stopping && code!==0){console.error(`[${label}] exited with ${code}`);stop(1);}});
 return p;
}
function stop(exitCode=0){if(stopping)return;stopping=true;for(const child of children){if(!child.killed)child.kill('SIGTERM');}setTimeout(()=>process.exit(exitCode),400).unref();}
process.on('SIGINT',()=>stop(0));process.on('SIGTERM',()=>stop(0));
async function waitHTTP(url){for(let i=0;i<100;i++){try{const r=await fetch(url);if(r.ok)return;}catch{}await sleep(180);}throw new Error(`Startup timed out: ${url}`)}
try{
 launch('core','go',['run','./cmd/ainbw-core','--addr',`127.0.0.1:${CORE_PORT}`]);
 await waitHTTP(`${CORE_URL}/api/v1/health`);
 launch('web','npm',['run','dev:web'],{AINBW_WEB_PORT:String(WEB_PORT),AINBW_CORE_URL:CORE_URL});
 await waitHTTP(`${WEB_URL}/`);
 launch('desktop','npm',['run','dev:desktop'],{AINBW_WEB_URL:WEB_URL,AINBW_CORE_URL:CORE_URL});
}catch(err){console.error(err.message);stop(1)}
