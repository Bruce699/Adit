import {weatherBoard} from './weathering.js';
export const DEFAULT_WEAR={amount:1,dust:1,scratches:.55,cracks:.41,bumps:.55,seed:24};
let seed=24;const rand=()=>{seed=(1664525*seed+1013904223)>>>0;return seed/4294967296;};
export const noiseCanvas=document.createElement('canvas');noiseCanvas.width=1024;noiseCanvas.height=256;const nctx=noiseCanvas.getContext('2d');const pixels=nctx.createImageData(1024,256);for(let i=0;i<pixels.data.length;i+=4){let v=108+rand()*40;pixels.data[i]=pixels.data[i+1]=pixels.data[i+2]=v;pixels.data[i+3]=255;}nctx.putImageData(pixels,0,0);
const routeColors={1:'#ee352e',2:'#ee352e',3:'#ee352e',4:'#00933c',5:'#00933c',6:'#00933c',7:'#b933ad',A:'#0039a6',C:'#0039a6',E:'#0039a6',B:'#ff6319',D:'#ff6319',F:'#ff6319',M:'#ff6319',G:'#6cbe45',J:'#996633',Z:'#996633',L:'#a7a9ac',N:'#fccc0a',Q:'#fccc0a',R:'#fccc0a',W:'#fccc0a',S:'#808183',SIR:'#0039a6'};
const base=document.createElement('canvas');base.width=1024;base.height=216;const bx=base.getContext('2d');bx.fillStyle='#222321';bx.fillRect(0,0,1024,216);for(let i=0;i<35000;i++){const v=rand()>.5?255:0;bx.fillStyle=`rgba(${v},${v},${v},${rand()*.025})`;bx.fillRect(rand()*1024,rand()*216,1,1);}bx.fillStyle='#f5f5f0';bx.fillRect(0,24,1024,2);
export function createBoardMaps(st,settings=DEFAULT_WEAR,seed=`${settings.seed}:0`){
 const c=document.createElement('canvas');c.width=1024;c.height=216;const ctx=c.getContext('2d');ctx.drawImage(base,0,0);
 const services=st.routes.length?st.routes:['S'];const count=services.length;const rows=count>3?2:1,cols=Math.ceil(count/rows);const radius=count===1?43:count<=3?29:23,step=radius*2+10;const blockWidth=cols*step+12;const nameWidth=1024-blockWidth-64;
 let label=st.name.replace(/\bAv\b/g,'Avenue').replace(/\bSt(?=-|$)/g,'Street').replace(/\bSq\b/g,'Square').replace(/\bPk\b/g,'Park').replace(/\bPkwy\b/g,'Parkway');
 let lines=label.endsWith(' Street')?[label.slice(0,-7),'Street Station']:[label,'Station'];
 let font=57.5;ctx.font=`500 ${font}px Arial,Helvetica,sans-serif`;
 if(ctx.measureText(lines[0]).width>nameWidth && !label.endsWith(' Street')){const words=label.split(' ');let best=lines;let score=Infinity;for(let i=1;i<words.length;i++){const trial=[words.slice(0,i).join(' '),words.slice(i).join(' ')+' Station'];const width=Math.max(...trial.map(t=>ctx.measureText(t).width));if(width<score){score=width;best=trial;}}lines=best;}
 while(Math.max(...lines.map(t=>ctx.measureText(t).width))>nameWidth&&font>28){font-=1;ctx.font=`500 ${font}px Arial,Helvetica,sans-serif`;}
 ctx.fillStyle='#f5f5f0';ctx.textBaseline='alphabetic';ctx.fillText(lines[0],24,92.5);ctx.fillText(lines[1],24,157.5);
 services.forEach((route,i)=>{const col=i%cols,row=Math.floor(i/cols);const x=1024-blockWidth/2+(col-(cols-1)/2)*step;const y=107+(row-(rows-1)/2)*step;ctx.beginPath();ctx.arc(x,y,radius,0,Math.PI*2);ctx.fillStyle=routeColors[route]||'#808183';ctx.fill();ctx.font=`500 ${route==='SIR'?radius*.8:radius*1.45}px Arial,Helvetica,sans-serif`;ctx.fillStyle=['N','Q','R','W'].includes(route)?'#171717':'#fff';ctx.textAlign='center';ctx.textBaseline='middle';ctx.fillText(route,x,y+2);});
 const heightCanvas=document.createElement('canvas');heightCanvas.width=1024;heightCanvas.height=216;
 const heightContext=heightCanvas.getContext('2d');heightContext.drawImage(noiseCanvas,0,0,1024,216);
 weatherBoard(ctx,heightContext,st.id,seed,settings);
 return {color:c,height:heightCanvas};
}

// Native signs use a baked height-map finish under the canvas's default light.
// The SwiftUI surface adds device-motion highlights without loading a web view.
export function createNativeBoard(st) {
 const maps=createBoardMaps(st),ctx=maps.color.getContext('2d'),w=maps.color.width,h=maps.color.height;
 const pixels=ctx.getImageData(0,0,w,h),height=maps.height.getContext('2d').getImageData(0,0,w,h).data;
 for(let y=0;y<h;y++)for(let x=0;x<w;x++){
  const i=(y*w+x)*4;
  const dx=(height[(y*w+Math.max(0,x-1))*4]-height[(y*w+Math.min(w-1,x+1))*4])/255;
  const dy=(height[(Math.max(0,y-1)*w+x)*4]-height[(Math.min(h-1,y+1)*w+x)*4])/255;
  const light=1+dx*.65+dy*.85;
  for(let channel=0;channel<3;channel++)pixels.data[i+channel]*=light;
 }
 ctx.putImageData(pixels,0,0);return maps.color;
}
