import {controls} from './lib/open-layer-controls.js';
(async()=>{
'use strict';
const composition = controls('Station composition', {
 columns: [12, 8, 24, 1], spacing: [32, 0, 100, 1], background: '#f6f5f2',
 fitCanvas: {type:'action', label:'Fit entire composition', run:()=>fit()},
});
const surface = controls('Sign materials & lighting', {
 angle: {type:'pad', x:[1,-75,75,1], y:[2,-65,65,1]},
 lightDirection: [-35,-180,180,1], lightHeight: [46,5,85,1],
 lightIntensity: [3.8,0,8,.1], roughness: [.62,0,1,.01], textureDepth: [.41,0,1,.01],
 metalness: [.18,0,1,.01], exposure: [1.05,.3,2,.05],
});
const s={yaw:1,pitch:2,distance:6.5};
const view={zoom:1,x:0,y:0,width:0,height:0};
const stage=document.getElementById('viewport');
const canvas=document.getElementById('scene'),root=document.getElementById('boards');
const response=await fetch('stations.json');if(!response.ok)throw Error('Station data could not be loaded.');
const stations=await response.json();
const renderer=new THREE.WebGLRenderer({canvas,antialias:true,alpha:true});
renderer.setPixelRatio(Math.min(devicePixelRatio,2));renderer.outputColorSpace=THREE.SRGBColorSpace;renderer.toneMapping=THREE.ACESFilmicToneMapping;renderer.toneMappingExposure=1.05;renderer.autoClear=false;
const scene=new THREE.Scene(),camera=new THREE.PerspectiveCamera(38,1,.1,50),group=new THREE.Group();scene.add(group);const deg=THREE.MathUtils.degToRad;
let seed=24;const rand=()=>{seed=(1664525*seed+1013904223)>>>0;return seed/4294967296;};
const noiseCanvas=document.createElement('canvas');noiseCanvas.width=1024;noiseCanvas.height=256;const nctx=noiseCanvas.getContext('2d');const pixels=nctx.createImageData(1024,256);for(let i=0;i<pixels.data.length;i+=4){let v=108+rand()*40;pixels.data[i]=pixels.data[i+1]=pixels.data[i+2]=v;pixels.data[i+3]=255;}nctx.putImageData(pixels,0,0);const bump=new THREE.CanvasTexture(noiseCanvas);bump.wrapS=bump.wrapT=THREE.RepeatWrapping;bump.repeat.set(3,3);
const face=new THREE.MeshPhysicalMaterial({map:null,roughness:.62,metalness:.18,bumpMap:bump,bumpScale:.41*.025,clearcoat:.16,clearcoatRoughness:.62*.8});
const metal=new THREE.MeshStandardMaterial({color:0x979a98,roughness:.38,metalness:.95});const darkMetal=new THREE.MeshStandardMaterial({color:0x292c2b,roughness:.46,metalness:.75});
function box(w,h,d,material,x,y,z){const mesh=new THREE.Mesh(new THREE.BoxGeometry(w,h,d),material);mesh.position.set(x,y,z);mesh.castShadow=true;mesh.receiveShadow=true;group.add(mesh);return mesh;}
box(4.84,1.03,.13,darkMetal,0,0,0);
const panel=new THREE.Mesh(new THREE.PlaneGeometry(4.78,1.008),face);panel.position.z=.068;group.add(panel);
const ambient=new THREE.HemisphereLight(0xe4edff,0x484132,1.4);scene.add(ambient);
const key=new THREE.DirectionalLight(0xfff2dc,3.8);key.castShadow=false;key.shadow.mapSize.set(1024,1024);scene.add(key);
const fill=new THREE.DirectionalLight(0xb2c9e8,.7);fill.position.set(-4,1,4);scene.add(fill);
const envCanvas=document.createElement('canvas');envCanvas.width=1024;envCanvas.height=512;const ectx=envCanvas.getContext('2d');ectx.fillStyle='#42484e';ectx.fillRect(0,0,1024,512);const gradient=ectx.createLinearGradient(0,0,0,512);gradient.addColorStop(0,'#c0c5cc');gradient.addColorStop(.45,'#626975');gradient.addColorStop(1,'#20201d');ectx.fillStyle=gradient;ectx.fillRect(0,0,1024,512);ectx.fillStyle='#ffffff';ectx.fillRect(420,80,280,62);ectx.fillStyle='#c3cfdd';ectx.fillRect(40,190,100,210);const envTexture=new THREE.CanvasTexture(envCanvas);envTexture.mapping=THREE.EquirectangularReflectionMapping;envTexture.colorSpace=THREE.SRGBColorSpace;const pmrem=new THREE.PMREMGenerator(renderer);const envTarget=pmrem.fromEquirectangular(envTexture);scene.environment=envTarget.texture;envTexture.dispose();pmrem.dispose();

camera.position.z=s.distance;
const cache=new Map();
const routeColors={1:'#ee352e',2:'#ee352e',3:'#ee352e',4:'#00933c',5:'#00933c',6:'#00933c',7:'#b933ad',A:'#0039a6',C:'#0039a6',E:'#0039a6',B:'#ff6319',D:'#ff6319',F:'#ff6319',M:'#ff6319',G:'#6cbe45',J:'#996633',Z:'#996633',L:'#a7a9ac',N:'#fccc0a',Q:'#fccc0a',R:'#fccc0a',W:'#fccc0a',S:'#808183',SIR:'#0039a6'};
const base=document.createElement('canvas');base.width=1024;base.height=216;const bx=base.getContext('2d');bx.fillStyle='#222321';bx.fillRect(0,0,1024,216);for(let i=0;i<35000;i++){const v=rand()>.5?255:0;bx.fillStyle=`rgba(${v},${v},${v},${rand()*.025})`;bx.fillRect(rand()*1024,rand()*216,1,1);}bx.fillStyle='#f5f5f0';bx.fillRect(0,24,1024,2);
function textureFor(st,width){
 const resolution=width*renderer.getPixelRatio()>512?1024:width*renderer.getPixelRatio()>256?512:256;
 const cacheKey=st.id+":"+resolution;
 if(cache.has(cacheKey)){const t=cache.get(cacheKey);cache.delete(cacheKey);cache.set(cacheKey,t);return t;}
 const c=document.createElement('canvas');c.width=1024;c.height=216;const ctx=c.getContext('2d');ctx.drawImage(base,0,0);
 const services=st.routes.length?st.routes:['S'];const count=services.length;const rows=count>3?2:1,cols=Math.ceil(count/rows);const radius=count===1?43:count<=3?29:23,step=radius*2+10;const blockWidth=cols*step+12;const nameWidth=1024-blockWidth-64;
 let label=st.name.replace(/\bAv\b/g,'Avenue').replace(/\bSt(?=-|$)/g,'Street').replace(/\bSq\b/g,'Square').replace(/\bPk\b/g,'Park').replace(/\bPkwy\b/g,'Parkway');
 let lines=label.endsWith(' Street')?[label.slice(0,-7),'Street Station']:[label,'Station'];
 let font=57.5;ctx.font=`500 ${font}px Arial,Helvetica,sans-serif`;
 if(ctx.measureText(lines[0]).width>nameWidth && !label.endsWith(' Street')){const words=label.split(' ');let best=lines;let score=Infinity;for(let i=1;i<words.length;i++){const trial=[words.slice(0,i).join(' '),words.slice(i).join(' ')+' Station'];const width=Math.max(...trial.map(t=>ctx.measureText(t).width));if(width<score){score=width;best=trial;}}lines=best;}
 while(Math.max(...lines.map(t=>ctx.measureText(t).width))>nameWidth&&font>28){font-=1;ctx.font=`500 ${font}px Arial,Helvetica,sans-serif`;}
 ctx.fillStyle='#f5f5f0';ctx.textBaseline='alphabetic';ctx.fillText(lines[0],24,92.5);ctx.fillText(lines[1],24,157.5);
 services.forEach((route,i)=>{const col=i%cols,row=Math.floor(i/cols);const x=1024-blockWidth/2+(col-(cols-1)/2)*step;const y=107+(row-(rows-1)/2)*step;ctx.beginPath();ctx.arc(x,y,radius,0,Math.PI*2);ctx.fillStyle=routeColors[route]||'#808183';ctx.fill();ctx.font=`500 ${route==='SIR'?radius*.8:radius*1.45}px Arial,Helvetica,sans-serif`;ctx.fillStyle=['N','Q','R','W'].includes(route)?'#171717':'#fff';ctx.textAlign='center';ctx.textBaseline='middle';ctx.fillText(route,x,y+2);});
 const scaled=document.createElement('canvas');scaled.width=resolution;scaled.height=Math.round(resolution*216/1024);scaled.getContext('2d').drawImage(c,0,0,scaled.width,scaled.height);
 const tex=new THREE.CanvasTexture(scaled);tex.colorSpace=THREE.SRGBColorSpace;tex.anisotropy=Math.min(8,renderer.capabilities.getMaxAnisotropy());cache.set(cacheKey,tex);return tex;
}
const fragment=document.createDocumentFragment();const tiles=stations.map(st=>{const el=document.createElement('div');el.className='board';el.tabIndex=0;el.setAttribute('role','img');el.setAttribute('aria-label',`${st.name}, ${st.routes.join(', ')}. Drag to tilt all boards.`);el.dataset.station=st.id;fragment.append(el);return {el,st};});root.append(fragment);
document.getElementById('caption').textContent=`${stations.length} station boards`;
let requested=false;function schedule(){if(!requested){requested=true;requestAnimationFrame(render);}}
function render(){requested=false;renderer.setScissorTest(false);renderer.clear();renderer.setScissorTest(true);group.rotation.set(deg(s.pitch),deg(s.yaw),0);let visible=0;
 // Keep projection tied to the unrotated sign, so tilting never changes camera scale.
 // The larger viewport leaves room for tilted corners without clipping at the tile edges.
 const overscan=6;
 for(const {el,st} of tiles){
  const r=el.getBoundingClientRect();
  if(r.bottom<0||r.top>innerHeight||r.right<0||r.left>innerWidth)continue;
  visible++;
  const aspect=r.width/r.height;
  const tangent=Math.max(.515,2.42/aspect)/(s.distance-.069);
  camera.aspect=aspect;
  camera.fov=THREE.MathUtils.radToDeg(2*Math.atan(tangent*overscan/.88));
  camera.updateProjectionMatrix();
  face.map=textureFor(st,r.width);
  const width=r.width*overscan,height=r.height*overscan;
  const left=r.left-(width-r.width)/2,top=r.top-(height-r.height)/2;
  renderer.setViewport(left,innerHeight-top-height,width,height);
  renderer.setScissor(0,0,innerWidth,innerHeight);
  renderer.clearDepth();
  renderer.render(scene,camera);
 }

 while(cache.size>Math.max(64,visible+8)){const key=cache.keys().next().value;cache.get(key).dispose();cache.delete(key);}
 canvas.dataset.yaw=s.yaw;canvas.dataset.pitch=s.pitch;canvas.dataset.visible=visible;
}
function updateView(){
 root.style.transform=`translate(${view.x}px,${view.y}px) scale(${view.zoom})`;
 document.getElementById('zoom-level').textContent=`${Math.round(view.zoom*100)}%`;
 canvas.dataset.zoom=view.zoom;
 schedule();
}
function fit(){
 view.zoom=Math.min((innerWidth-48)/view.width,(innerHeight-160)/view.height,1);
 view.x=(innerWidth-view.width*view.zoom)/2;
 view.y=80+(innerHeight-160-view.height*view.zoom)/2;
 updateView();
}
function zoomAt(next,x=innerWidth/2,y=innerHeight/2){
 next=THREE.MathUtils.clamp(next,.035,3);
 const ratio=next/view.zoom;
 view.x=x-(x-view.x)*ratio;view.y=y-(y-view.y)*ratio;view.zoom=next;updateView();
}
function layout(){
 const v=composition.get(),cols=v.columns,rows=Math.ceil(stations.length/cols);
 root.style.gridTemplateColumns=`repeat(${cols},320px)`;root.style.gap=`${v.spacing}px`;
 view.width=cols*320+(cols-1)*v.spacing;view.height=rows*(320/4.7)+(rows-1)*v.spacing;
 root.style.width=`${view.width}px`;
 document.documentElement.style.background=v.background;
 document.documentElement.style.setProperty("--canvas-background",v.background);
 fit();
}
let spring=null;
function stopSpring(){if(spring)cancelAnimationFrame(spring.frame);spring=null;}
function returnTilt(yaw,pitch){
 stopSpring();
 if(matchMedia('(prefers-reduced-motion: reduce)').matches){s.yaw=yaw;s.pitch=pitch;schedule();return;}
 const motion={yaw,pitch,fromYaw:s.yaw,fromPitch:s.pitch,start:performance.now(),frame:0};
 spring=motion;
 function tick(now){
  const t=(now-motion.start)/1000;
  // A lightly underdamped spring: gentle overshoot, then a quiet settle.
  const decay=Math.exp(-10*t)*(Math.cos(8*t)+1.25*Math.sin(8*t));
  s.yaw=yaw+(motion.fromYaw-yaw)*decay;s.pitch=pitch+(motion.fromPitch-pitch)*decay;
  if(t>=1.1){s.yaw=yaw;s.pitch=pitch;spring=null;}else motion.frame=requestAnimationFrame(tick);
  schedule();
 }
 motion.frame=requestAnimationFrame(tick);
}
let previousAngle=null;
function applySurface(){
 const v=surface.get();
 if(!previousAngle||v.angle.x!==previousAngle.x||v.angle.y!==previousAngle.y){stopSpring();s.yaw=v.angle.x;s.pitch=v.angle.y;previousAngle={...v.angle};}
 face.roughness=v.roughness;face.bumpScale=v.textureDepth*.025;
 face.clearcoatRoughness=v.roughness*.8;face.metalness=v.metalness;
 const a=deg(v.lightDirection),h=deg(v.lightHeight);
 key.position.set(Math.sin(a)*6*Math.cos(h),Math.sin(h)*6,Math.cos(a)*6*Math.cos(h));
 key.intensity=v.lightIntensity;renderer.toneMappingExposure=v.exposure;schedule();
}
composition.subscribe(layout);surface.subscribe(applySurface);
function resize(){renderer.setSize(innerWidth,innerHeight,false);fit();}
window.addEventListener('resize',resize);
// Trackpad pinches arrive as Ctrl+wheel; ordinary scrolling pans on both axes.
const panSensitivity=1.25, pinchSensitivity=1.15;
stage.addEventListener('wheel',e=>{
 e.preventDefault();
 const unit=e.deltaMode===1?16:e.deltaMode===2?innerHeight:1;
 if(e.ctrlKey){zoomAt(view.zoom*Math.exp(-e.deltaY*unit*.01*pinchSensitivity),e.clientX,e.clientY);return;}
 // Shift+wheel also supports horizontal panning with a conventional mouse.
 const horizontal=e.shiftKey&&e.deltaX===0;
 view.x-=(horizontal?e.deltaY:e.deltaX)*unit*panSensitivity;
 view.y-=(horizontal?0:e.deltaY)*unit*panSensitivity;
 updateView();
},{passive:false});
document.getElementById('zoom-in').onclick=()=>zoomAt(view.zoom*1.3);
document.getElementById('zoom-out').onclick=()=>zoomAt(view.zoom/1.3);
document.getElementById('fit').onclick=fit;
document.getElementById('actual-size').onclick=()=>zoomAt(1);
const pointers=new Map();let drag=null,pinch=null;
stage.addEventListener('pointerdown',e=>{
 if(e.button!==0&&e.button!==1)return;
 e.preventDefault();stage.setPointerCapture(e.pointerId);pointers.set(e.pointerId,{x:e.clientX,y:e.clientY});
 const el=e.target.closest('.board'),tilt=!!el&&!e.shiftKey&&e.button===0;
 const restYaw=drag?.restYaw??spring?.yaw??s.yaw,restPitch=drag?.restPitch??spring?.pitch??s.pitch;
 if(tilt)stopSpring();
 drag={x:e.clientX,y:e.clientY,panX:view.x,panY:view.y,yaw:s.yaw,pitch:s.pitch,restYaw,restPitch,tilt};
 stage.classList.add('is-dragging');
 if(pointers.size===2){const [a,b]=[...pointers.values()];pinch={distance:Math.hypot(a.x-b.x,a.y-b.y),zoom:view.zoom,x:(a.x+b.x)/2,y:(a.y+b.y)/2};returnTilt(restYaw,restPitch);drag=null;}
});
stage.addEventListener('pointermove',e=>{
 if(!pointers.has(e.pointerId))return;pointers.set(e.pointerId,{x:e.clientX,y:e.clientY});
 if(pinch&&pointers.size===2){const [a,b]=[...pointers.values()],x=(a.x+b.x)/2,y=(a.y+b.y)/2;
 zoomAt(pinch.zoom*Math.pow(Math.hypot(a.x-b.x,a.y-b.y)/Math.max(1,pinch.distance),pinchSensitivity),pinch.x,pinch.y);
 view.x+=(x-pinch.x)*panSensitivity;view.y+=(y-pinch.y)*panSensitivity;pinch.x=x;pinch.y=y;updateView();return;}
 if(!drag)return;
 if(drag.tilt){s.yaw=THREE.MathUtils.clamp(drag.yaw+(e.clientX-drag.x)*.28,-75,75);s.pitch=THREE.MathUtils.clamp(drag.pitch+(e.clientY-drag.y)*.28,-65,65);schedule();}
 else{view.x=drag.panX+(e.clientX-drag.x)*panSensitivity;view.y=drag.panY+(e.clientY-drag.y)*panSensitivity;updateView();}
});
function end(e){
 if(!pointers.delete(e.pointerId))return;
 if(drag?.tilt)returnTilt(drag.restYaw,drag.restPitch);
 drag=null;pinch=null;
 if(!pointers.size)stage.classList.remove('is-dragging');
}
stage.addEventListener('pointerup',end);stage.addEventListener('pointercancel',end);stage.addEventListener('lostpointercapture',end);
window.addEventListener('keydown',e=>{
 if(e.target.matches('input,textarea,select'))return;
 if(['+','=','-','0'].includes(e.key)){e.preventDefault();if(e.key==='0')fit();else zoomAt(view.zoom*(e.key==='-'?1/1.3:1.3));return;}
 if(!e.target.closest('.board')||!['ArrowLeft','ArrowRight','ArrowUp','ArrowDown'].includes(e.key))return;
 e.preventDefault();stopSpring();const step=e.shiftKey?5:1;
 if(e.key==='ArrowLeft')s.yaw-=step;if(e.key==='ArrowRight')s.yaw+=step;if(e.key==='ArrowUp')s.pitch-=step;if(e.key==='ArrowDown')s.pitch+=step;
 s.yaw=THREE.MathUtils.clamp(s.yaw,-75,75);s.pitch=THREE.MathUtils.clamp(s.pitch,-65,65);schedule();
});
layout();applySurface();resize();

})().catch(error=>{const el=document.getElementById('error');el.hidden=false;el.textContent='Unable to display the station canvas: '+error.message;});
