import type { ButtonHTMLAttributes } from 'react';
export function Button(props:ButtonHTMLAttributes<HTMLButtonElement>){return <button {...props} style={{border:'1px solid #454545',borderRadius:9,padding:'9px 15px',color:'#eee',background:'#292929',cursor:'pointer',...props.style}}/>;}
