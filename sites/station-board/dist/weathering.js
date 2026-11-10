// Seeded, station-specific enamel wear. Marks stay fixed through rotation and zoom.
export function stationRandom(id, seed) {
 let state=2166136261;
 for(const char of `${id}:${seed}`){state^=char.charCodeAt(0);state=Math.imul(state,16777619);}
 return ()=>{state+=0x6D2B79F5;let n=state;n=Math.imul(n^(n>>>15),n|1);n^=n+Math.imul(n^(n>>>7),n|61);return ((n^(n>>>14))>>>0)/4294967296;};
}
export function weatherBoard(color, height, id, seed, settings) {
 const random=stationRandom(id,seed),w=color.canvas.width,h=color.canvas.height;
 const amount=settings.amount;
 if(!amount)return;
 color.save();height.save();
 color.lineCap=height.lineCap='round';color.lineJoin=height.lineJoin='round';
 function spot(ctx,x,y,rx,ry,rgb,opacity){
  ctx.save();ctx.translate(x,y);ctx.scale(rx,ry);
  const g=ctx.createRadialGradient(0,0,0,0,0,1);g.addColorStop(0,`rgba(${rgb},${opacity})`);g.addColorStop(1,`rgba(${rgb},0)`);
  ctx.fillStyle=g;ctx.fillRect(-1,-1,2,2);ctx.restore();
 }
 // Broad, faint grime with irregular dust clusters, biased toward seams and edges.
 const dust=amount*settings.dust;
 for(let cluster=0;cluster<14;cluster++){
  const x=random()*w,y=cluster<8?(random()<.5?random()*18:h-random()*18):random()*h;
  const rx=20+random()*90,ry=4+random()*19;
  spot(color,x,y,rx,ry,'157,146,120',dust*(.025+random()*.07));
  for(let i=0;i<45;i++){
   const px=x+(random()+random()+random()-1.5)*rx,py=y+(random()+random()-1.5)*ry;
   const radius=.25+Math.pow(random(),4)*2;
   color.fillStyle=`rgba(184,171,142,${dust*(.06+random()*.25)})`;
   color.beginPath();color.arc(px,py,radius,0,Math.PI*2);color.fill();
  }
 }
 // Small surface blisters and shallow dents use a height map, not painted highlights.
 const bumps=amount*settings.bumps;
 for(let i=0;i<38;i++){
  const x=random()*w,y=random()*h,r=1.5+Math.pow(random(),2)*16;
  spot(height,x,y,r,r*(.45+random()*.5),random()<.7?'220,220,220':'30,30,30',bumps*(.2+random()*.5));
 }
 // Scuffs form families with a shared direction, interrupted and varied in length.
 const scratches=amount*settings.scratches;
 for(let cluster=0;cluster<8;cluster++){
  const x=random()*w,y=random()*h,angle=-.25+random()*.5;
  for(let i=0;i<6;i++){
   const px=x+(random()-.5)*50,py=y+(random()-.5)*18,length=5+Math.pow(random(),2)*110;
   const endX=px+Math.cos(angle)*length,endY=py+Math.sin(angle)*length;
   color.strokeStyle=`rgba(191,186,171,${scratches*(.12+random()*.42)})`;
   color.lineWidth=.35+random()*.9;
   color.beginPath();color.moveTo(px,py);color.lineTo(endX,endY);color.stroke();
   height.strokeStyle=`rgba(20,20,20,${scratches*.65})`;height.lineWidth=color.lineWidth+ .6;
   height.beginPath();height.moveTo(px,py);height.lineTo(endX,endY);height.stroke();
  }
 }
 // Hairline fractures start at the enamel's edge, with short, uneven branches.
 const cracks=amount*settings.cracks;
 for(let i=0;i<4;i++){
  let x=random()*w,y=random()<.5?0:h;
  const direction=y===0?1:-1,dx=(random()-.5)*8,steps=3+Math.floor(random()*6);
  const points=[[x,y]];
  for(let j=0;j<steps;j++){x+=dx+(random()-.5)*9;y+=direction*(2+random()*5);points.push([x,y]);}
  function line(ctx,offset){ctx.beginPath();points.forEach(([x,y],i)=>i?ctx.lineTo(x+offset,y):ctx.moveTo(x+offset,y));ctx.stroke();}
  color.lineWidth=.8;color.strokeStyle=`rgba(5,7,6,${cracks*.9})`;line(color,0);
  color.lineWidth=.45;color.strokeStyle=`rgba(166,158,138,${cracks*.5})`;line(color,.8);
  height.lineWidth=1.2;height.strokeStyle=`rgba(0,0,0,${cracks})`;line(height,0);
  if(points.length>4){const [bx,by]=points[3];color.strokeStyle=`rgba(8,9,8,${cracks*.7})`;color.beginPath();color.moveTo(bx,by);color.lineTo(bx-4+random()*8,by+direction*5);color.lineTo(bx-8+random()*16,by+direction*10);color.stroke();}
 }
 // Tiny chips collect along the rim instead of uniformly covering the lettering.
 for(let i=0;i<85;i++){
  const x=random()*w,y=random()<.5?random()*2:h-random()*2;
  color.fillStyle=`rgba(161,158,145,${scratches*(.1+random()*.3)})`;
  color.fillRect(x,y,.5+random()*5,.3+random());
 }
 color.restore();height.restore();
}
