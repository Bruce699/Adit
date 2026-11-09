(async()=>{
'use strict';
const s={yaw:1,pitch:2,light:-35,height:46,rough:.62,grain:.41,distance:6.5};
const canvas=document.getElementById('scene'),root=document.getElementById('boards');
const response=await fetch('stations.json');if(!response.ok)throw Error('Station data could not be loaded.');
const stations=await response.json();
const renderer=new THREE.WebGLRenderer({canvas,antialias:true,alpha:true});
renderer.setPixelRatio(Math.min(devicePixelRatio,2));renderer.outputColorSpace=THREE.SRGBColorSpace;renderer.toneMapping=THREE.ACESFilmicToneMapping;renderer.toneMappingExposure=1.05;renderer.autoClear=false;
const scene=new THREE.Scene(),camera=new THREE.PerspectiveCamera(38,1,.1,50),group=new THREE.Group();scene.add(group);const deg=THREE.MathUtils.degToRad;
let seed=24;const rand=()=>{seed=(1664525*seed+1013904223)>>>0;return seed/4294967296;};
const noiseCanvas=document.createElement('canvas');noiseCanvas.width=1024;noiseCanvas.height=256;const nctx=noiseCanvas.getContext('2d');const pixels=nctx.createImageData(1024,256);for(let i=0;i<pixels.data.length;i+=4){let v=108+rand()*40;pixels.data[i]=pixels.data[i+1]=pixels.data[i+2]=v;pixels.data[i+3]=255;}nctx.putImageData(pixels,0,0);const bump=new THREE.CanvasTexture(noiseCanvas);bump.wrapS=bump.wrapT=THREE.RepeatWrapping;bump.repeat.set(3,3);
const face=new THREE.MeshPhysicalMaterial({map:null,roughness:s.rough,metalness:.18,bumpMap:bump,bumpScale:s.grain*.025,clearcoat:.16,clearcoatRoughness:s.rough*.8});
const metal=new THREE.MeshStandardMaterial({color:0x979a98,roughness:.38,metalness:.95});const darkMetal=new THREE.MeshStandardMaterial({color:0x292c2b,roughness:.46,metalness:.75});
function box(w,h,d,material,x,y,z){const mesh=new THREE.Mesh(new THREE.BoxGeometry(w,h,d),material);mesh.position.set(x,y,z);mesh.castShadow=true;mesh.receiveShadow=true;group.add(mesh);return mesh;}
box(4.84,1.03,.13,darkMetal,0,0,0);
const panel=new THREE.Mesh(new THREE.PlaneGeometry(4.78,1.008),face);panel.position.z=.068;group.add(panel);
const ambient=new THREE.HemisphereLight(0xe4edff,0x484132,1.4);scene.add(ambient);
const key=new THREE.DirectionalLight(0xfff2dc,3.8);key.castShadow=false;key.shadow.mapSize.set(1024,1024);scene.add(key);
const fill=new THREE.DirectionalLight(0xb2c9e8,.7);fill.position.set(-4,1,4);scene.add(fill);
const envCanvas=document.createElement('canvas');envCanvas.width=1024;envCanvas.height=512;const ectx=envCanvas.getContext('2d');ectx.fillStyle='#42484e';ectx.fillRect(0,0,1024,512);const gradient=ectx.createLinearGradient(0,0,0,512);gradient.addColorStop(0,'#c0c5cc');gradient.addColorStop(.45,'#626975');gradient.addColorStop(1,'#20201d');ectx.fillStyle=gradient;ectx.fillRect(0,0,1024,512);ectx.fillStyle='#ffffff';ectx.fillRect(420,80,280,62);ectx.fillStyle='#c3cfdd';ectx.fillRect(40,190,100,210);const envTexture=new THREE.CanvasTexture(envCanvas);envTexture.mapping=THREE.EquirectangularReflectionMapping;envTexture.colorSpace=THREE.SRGBColorSpace;const pmrem=new THREE.PMREMGenerator(renderer);const envTarget=pmrem.fromEquirectangular(envTexture);scene.environment=envTarget.texture;envTexture.dispose();pmrem.dispose();
metal.roughness=.18+s.rough*.45;
const a=deg(s.light),h=deg(s.height);key.position.set(Math.sin(a)*6*Math.cos(h),Math.sin(h)*6,Math.cos(a)*6*Math.cos(h));
camera.position.z=s.distance;
const cache=new Map();
const routeColors={1:'#ee352e',2:'#ee352e',3:'#ee352e',4:'#00933c',5:'#00933c',6:'#00933c',7:'#b933ad',A:'#0039a6',C:'#0039a6',E:'#0039a6',B:'#ff6319',D:'#ff6319',F:'#ff6319',M:'#ff6319',G:'#6cbe45',J:'#996633',Z:'#996633',L:'#a7a9ac',N:'#fccc0a',Q:'#fccc0a',R:'#fccc0a',W:'#fccc0a',S:'#808183',SIR:'#0039a6'};
const base=document.createElement('canvas');base.width=1024;base.height=216;const bx=base.getContext('2d');bx.fillStyle='#222321';bx.fillRect(0,0,1024,216);for(let i=0;i<35000;i++){const v=rand()>.5?255:0;bx.fillStyle=`rgba(${v},${v},${v},${rand()*.025})`;bx.fillRect(rand()*1024,rand()*216,1,1);}bx.fillStyle='#f5f5f0';bx.fillRect(0,24,1024,2);
function textureFor(st){
 if(cache.has(st.id)){const t=cache.get(st.id);cache.delete(st.id);cache.set(st.id,t);return t;}
 const c=document.createElement('canvas');c.width=1024;c.height=216;const ctx=c.getContext('2d');ctx.drawImage(base,0,0);
 const services=st.routes.length?st.routes:['S'];const count=services.length;const rows=count>3?2:1,cols=Math.ceil(count/rows);const radius=count===1?43:count<=3?29:23,step=radius*2+10;const blockWidth=cols*step+12;const nameWidth=1024-blockWidth-64;
 let label=st.name.replace(/\bAv\b/g,'Avenue').replace(/\bSt(?=-|$)/g,'Street').replace(/\bSq\b/g,'Square').replace(/\bPk\b/g,'Park').replace(/\bPkwy\b/g,'Parkway');
 let lines=label.endsWith(' Street')?[label.slice(0,-7),'Street Station']:[label,'Station'];
 let font=57.5;ctx.font=`500 ${font}px Arial,Helvetica,sans-serif`;
 if(ctx.measureText(lines[0]).width>nameWidth && !label.endsWith(' Street')){const words=label.split(' ');let best=lines;let score=Infinity;for(let i=1;i<words.length;i++){const trial=[words.slice(0,i).join(' '),words.slice(i).join(' ')+' Station'];const width=Math.max(...trial.map(t=>ctx.measureText(t).width));if(width<score){score=width;best=trial;}}lines=best;}
 while(Math.max(...lines.map(t=>ctx.measureText(t).width))>nameWidth&&font>28){font-=1;ctx.font=`500 ${font}px Arial,Helvetica,sans-serif`;}
 ctx.fillStyle='#f5f5f0';ctx.textBaseline='alphabetic';ctx.fillText(lines[0],24,92.5);ctx.fillText(lines[1],24,157.5);
 services.forEach((route,i)=>{const col=i%cols,row=Math.floor(i/cols);const x=1024-blockWidth/2+(col-(cols-1)/2)*step;const y=107+(row-(rows-1)/2)*step;ctx.beginPath();ctx.arc(x,y,radius,0,Math.PI*2);ctx.fillStyle=routeColors[route]||'#808183';ctx.fill();ctx.font=`500 ${route==='SIR'?radius*.8:radius*1.45}px Arial,Helvetica,sans-serif`;ctx.fillStyle=['N','Q','R','W'].includes(route)?'#171717':'#fff';ctx.textAlign='center';ctx.textBaseline='middle';ctx.fillText(route,x,y+2);});
 const tex=new THREE.CanvasTexture(c);tex.colorSpace=THREE.SRGBColorSpace;tex.anisotropy=Math.min(8,renderer.capabilities.getMaxAnisotropy());cache.set(st.id,tex);return tex;
}
const fragment=document.createDocumentFragment();const tiles=stations.map(st=>{const el=document.createElement('div');el.className='board';el.tabIndex=0;el.setAttribute('role','img');el.setAttribute('aria-label',`${st.name}, ${st.routes.join(', ')}. Drag to tilt all boards.`);el.dataset.station=st.id;fragment.append(el);return {el,st};});root.append(fragment);
document.getElementById('caption').textContent=`${stations.length} station boards · Drag any board to tilt all · Scroll to explore`;
let requested=false;function schedule(){if(!requested){requested=true;requestAnimationFrame(render);}}
function render(){requested=false;renderer.setScissorTest(false);renderer.clear();renderer.setScissorTest(true);group.rotation.set(deg(s.pitch),deg(s.yaw),0);let visible=0;
 for(const {el,st} of tiles){const r=el.getBoundingClientRect();if(r.bottom<0||r.top>innerHeight||r.right<0||r.left>innerWidth)continue;visible++;const aspect=r.width/r.height;camera.aspect=aspect;let tangent=0;for(const x of [-2.42,2.42])for(const y of [-.515,.515])for(const z of [-.065,.069]){const point=new THREE.Vector3(x,y,z).applyEuler(group.rotation);tangent=Math.max(tangent,Math.abs(point.y)/(s.distance-point.z),Math.abs(point.x)/(s.distance-point.z)/aspect);}camera.fov=THREE.MathUtils.radToDeg(2*Math.atan(tangent/.88));camera.updateProjectionMatrix();face.map=textureFor(st);renderer.setViewport(r.left,innerHeight-r.bottom,r.width,r.height);renderer.setScissor(Math.max(0,r.left),Math.max(0,innerHeight-r.bottom),Math.min(r.width,innerWidth-r.left),Math.min(innerHeight,r.bottom)-Math.max(0,r.top));renderer.render(scene,camera);}
 while(cache.size>Math.max(64,visible+8)){const key=cache.keys().next().value;cache.get(key).dispose();cache.delete(key);}
 canvas.dataset.yaw=s.yaw;canvas.dataset.pitch=s.pitch;canvas.dataset.visible=visible;
}
function resize(){renderer.setSize(innerWidth,innerHeight,false);schedule();}window.addEventListener('resize',resize);window.addEventListener('scroll',schedule,{passive:true});
let drag=null;root.addEventListener('pointerdown',e=>{const el=e.target.closest('.board');if(!el||e.button!==0)return;drag={x:e.clientX,y:e.clientY,yaw:s.yaw,pitch:s.pitch,el};el.setPointerCapture(e.pointerId);});root.addEventListener('pointermove',e=>{if(!drag)return;s.yaw=THREE.MathUtils.clamp(drag.yaw+(e.clientX-drag.x)*.28,-75,75);s.pitch=THREE.MathUtils.clamp(drag.pitch+(e.clientY-drag.y)*.28,-65,65);schedule();});function end(){drag=null;}root.addEventListener('pointerup',end);root.addEventListener('pointercancel',end);root.addEventListener('lostpointercapture',end);
root.addEventListener('keydown',e=>{if(!e.target.closest('.board')||!['ArrowLeft','ArrowRight','ArrowUp','ArrowDown'].includes(e.key))return;e.preventDefault();const step=e.shiftKey?5:1;if(e.key==='ArrowLeft')s.yaw-=step;if(e.key==='ArrowRight')s.yaw+=step;if(e.key==='ArrowUp')s.pitch-=step;if(e.key==='ArrowDown')s.pitch+=step;s.yaw=THREE.MathUtils.clamp(s.yaw,-75,75);s.pitch=THREE.MathUtils.clamp(s.pitch,-65,65);schedule();});
resize();
})().catch(error=>{const el=document.getElementById('error');el.hidden=false;el.textContent='Unable to display the station canvas: '+error.message;});
