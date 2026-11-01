import type { HTMLAttributes } from 'react';
export function Card(props:HTMLAttributes<HTMLDivElement>){return <div {...props} style={{border:'1px solid #343434',borderRadius:12,background:'#212121',padding:19,...props.style}}/>;}
