// Usage: node scripts/export-station-boards.mjs <CDP websocket URL> <preview URL>
// Uses the canvas's shared seeded painter; no image generation or remote assets.
import fs from 'node:fs/promises';
import path from 'node:path';
const [cdp,preview]=process.argv.slice(2);
if(!cdp||!preview)throw Error('Provide the browser CDP websocket URL and preview URL.');
const socket=new WebSocket(cdp),pending=new Map();let sequence=0,exportTarget;
await new Promise((resolve,reject)=>{socket.onopen=resolve;socket.onerror=reject;});
socket.onmessage=event=>{const result=JSON.parse(event.data);if(result.id){const p=pending.get(result.id);pending.delete(result.id);if(result.error)p.reject(Error(result.error.message));else p.resolve(result.result);}};
function call(method,params={},sessionId){return new Promise((resolve,reject)=>{const id=++sequence;pending.set(id,{resolve,reject});socket.send(JSON.stringify({id,method,params,...(sessionId?{sessionId}:{})}));});}
try{
 const {targetId}=await call('Target.createTarget',{url:'about:blank'});exportTarget=targetId;
 const {sessionId}=await call('Target.attachToTarget',{targetId,flatten:true});
 // This dedicated export tab ignores live reloads caused by the asset writes.
 await call('Page.addScriptToEvaluateOnNewDocument',{source:'window.__olLive=1;'},sessionId);
 await call('Page.navigate',{url:new URL('board-fragment.html',preview).href},sessionId);
 await new Promise(resolve=>setTimeout(resolve,1500));
 const stations=JSON.parse(await fs.readFile('sites/station-board/dist/stations.json','utf8'));
 for(const [index,station] of stations.entries()){
  const expression=`(async()=>{const {createNativeBoard}=await import(${JSON.stringify(new URL('board-texture.js',preview).href)});const board=createNativeBoard(${JSON.stringify(station)});return board.toDataURL('image/jpeg',.94).split(',')[1];})()`;
  const result=await call('Runtime.evaluate',{expression,awaitPromise:true,returnByValue:true},sessionId);
  if(result.exceptionDetails||typeof result.result?.value!=='string')throw Error(`Export failed: ${station.id}`);
  const directory=path.join('Adit/Assets.xcassets',`station-${station.id}.imageset`);
  await fs.mkdir(directory,{recursive:true});
  await fs.writeFile(path.join(directory,'board.jpg'),Buffer.from(result.result.value,'base64'));
  await fs.writeFile(path.join(directory,'Contents.json'),JSON.stringify({images:[{filename:'board.jpg',idiom:'universal'}],info:{author:'xcode',version:1}},null,2)+'\n');
  if((index+1)%100===0)console.log(`Exported ${index+1}/${stations.length} boards`);
 }
 console.log(`Exported all ${stations.length} native board assets.`);
 const catalogPath='Adit/StationBoards.swift';
 const catalog=await fs.readFile(catalogPath,'utf8');
 const quote=value=>JSON.stringify(value);
 const records=stations.map(st=>`    Board(id: ${quote(st.id)}, name: ${quote(st.name)}, routes: [${st.routes.map(quote).join(', ')}], borough: ${quote(st.borough)}, line: ${quote(st.line)}),`).join('\n');
 await fs.writeFile(catalogPath,catalog.replace(/(    \/\/ BEGIN GENERATED STATIONS\n)[\s\S]*?(    \/\/ END GENERATED STATIONS)/,(_,start,end)=>start+records+'\n'+end));
}finally{if(exportTarget)await call('Target.closeTarget',{targetId:exportTarget}).catch(()=>{});socket.close();}

