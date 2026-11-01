import type { ReactNode } from 'react';
export function Modal({open,onClose,title,children}:{open:boolean;onClose:()=>void;title:string;children:ReactNode}){
 if(!open)return null;
 return <div onClick={onClose} style={{position:'fixed',inset:0,background:'#0009',display:'grid',placeItems:'center',zIndex:500}}><div role="dialog" aria-modal="true" onClick={e=>e.stopPropagation()} style={{width:460,maxWidth:'calc(100vw - 32px)',background:'#252525',padding:24,borderRadius:18,boxShadow:'0 12px 40px #0007'}}><div style={{display:'flex',justifyContent:'space-between',alignItems:'center'}}><strong>{title}</strong><button onClick={onClose} aria-label="关闭弹窗" style={{background:'none',border:0,color:'white',cursor:'pointer'}}>×</button></div><p style={{color:'#bbb',lineHeight:1.7}}>{children}</p></div></div>;
}
