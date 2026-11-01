import { useEffect, useState } from 'react';
import { AINBWClient, type CoreHealth, type Capability } from '@ainbw/sdk';
import { Button, Card, Modal } from '@ainbw/ui';
const api = new AINBWClient();

declare global { interface Window { electronAPI?: { isElectron: boolean; windowAction: (action: string)=>void } } }
export default function App() {
  const [developer, setDeveloper] = useState(location.hash === '#/developer');
  const [health, setHealth] = useState<CoreHealth | null>(null);
  const [capabilities, setCapabilities] = useState<Capability[]>([]);
  const [modal, setModal] = useState(false);
  useEffect(() => {
    const onHash = () => setDeveloper(location.hash === '#/developer');
    const onMessage = (e: MessageEvent) => {
      if(e.origin !== location.origin || e.data?.type !== 'ainbw.windowAction') return;
      const action = String(e.data?.action);
      if(['close','maximize','minimize'].includes(action)) window.electronAPI?.windowAction(action);
    };
    window.addEventListener('hashchange', onHash);
    window.addEventListener('message', onMessage);
    return () => {window.removeEventListener('hashchange', onHash);window.removeEventListener('message', onMessage);};
  }, []);
  useEffect(() => {
    if(!developer) return;
    api.health().then(setHealth).catch(()=>setHealth(null));
    api.capabilities().then(r=>setCapabilities(r.capabilities)).catch(()=>setCapabilities([]));
  }, [developer]);
  if(!developer) return <iframe className="legacy-shell" title="AI Native Workbench Shell" src="/shell/index.html?embedded=1" />;
  return <main className="developer-view">
    <div className="developer-head"><div><span>AINBW / 开发者中心</span><h1>开发者中心 <small>Developer Center</small></h1><p>可用基础设施与契约目录 · v0.2.0 工程基线</p></div><Button onClick={()=>{location.hash='';setDeveloper(false)}}>返回工作台</Button></div>
    <section className="dev-status"><Card><strong>Go Microkernel</strong><p>{health ? `在线 · ${health.version}`:'暂未连接 · 请启动 Go 内核'}</p></Card><Card><strong>官方公共 SDK</strong><p>TypeScript · Go 契约</p></Card><Card><strong>业务插件</strong><p>静态发现与清单验证已接入</p></Card></section>
    <h2>公开能力注册表</h2><section className="cap-grid">{capabilities.length ? capabilities.map(cap=><Card key={cap.id}><strong>{cap.name}</strong><p>{cap.description}</p><code>{cap.id}</code></Card>) : <Card><strong>等待内核连接</strong><p>此页通过 Go Core API 查询资源，未连接时不会伪造在线数据。</p></Card>}</section>
    <div className="dev-foot"><Button onClick={()=>setModal(true)}>查看 SDK 使用说明</Button><a href="/shell/index.html?embedded=1" target="_blank" rel="noreferrer">单独打开旧版 Shell</a></div>
    <Modal open={modal} onClose={()=>setModal(false)} title="官方 SDK">通过 @ainbw/sdk 查询 Core API；业务插件通过 Manifest 声明公开的视图、服务、数据和 SDK。详细文档参见 docs/。</Modal>
  </main>;
}
