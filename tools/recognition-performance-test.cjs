// No browser or paid API required. Optional baseline HTML compares full local results.
// node tools/recognition-performance-test.cjs [baseline.html]
const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict'),path=require('node:path');
const root=path.resolve(__dirname,'..'),palette=JSON.parse(fs.readFileSync(path.join(root,'color_card/MRAD_color.json'),'utf8'));
const silent=new Proxy({}, {get:()=>()=>{}});
function load(file){
  const nodes=new Map,document={querySelector(selector){if(!nodes.has(selector))nodes.set(selector,{style:{},classList:{toggle(){}},addEventListener(){},querySelectorAll(){return[]},textContent:''});return nodes.get(selector)},querySelectorAll(){return[]}};
  const storage=new Map,localStorage={getItem:key=>storage.has(key)?storage.get(key):null,setItem:(key,value)=>storage.set(key,String(value)),removeItem:key=>storage.delete(key)};
  const context=vm.createContext({document,console:silent,performance,setTimeout,clearTimeout,AbortController,Uint8Array,Uint16Array,Uint32Array,Float64Array,localStorage,fetch:async()=>{throw Error('Unexpected network')}});
  const script=fs.readFileSync(file,'utf8').match(/<script>([\s\S]*?)<\/script>/)[1];
  vm.runInContext(script,context);context.paletteData=structuredClone(palette);
  vm.runInContext('palette=paletteData;for(const p of palette){const mask=bitmapLabelMask(p.id);p._templates=mask?[{mask,dilated:dilate(mask),count:mask.reduce((a,b)=>a+b,0),holes:maskHoles(mask),bitmap:true}]:[]}',context);
  return context;
}
const current=load(path.join(root,'preview/index.html'));
function evaluate(context,code){return vm.runInContext(code,context)}
function plain(value){return JSON.parse(JSON.stringify(value))}
function referenceScore(actual,actualDilated,template,holes){
  let count=0,matchedActual=0,matchedTemplate=0,exact=0;
  for(let i=0;i<actual.length;i++){if(actual[i]){count++;if(template.dilated[i])matchedActual++;if(template.mask[i])exact++}if(template.mask[i]&&actualDilated[i])matchedTemplate++}
  const penalty=Math.min(.18,Math.abs(holes-template.holes)*.06);
  return .35*matchedActual/Math.max(1,count)+.35*matchedTemplate/Math.max(1,template.count)+.30*(2*exact/Math.max(1,count+template.count))-penalty;
}
async function main(){
  current.aiVertical=[{index:0,pos:0},{index:5,pos:250},{index:10,pos:500},{index:15,pos:750}];
  current.aiHorizontal=[{index:0,pos:0},{index:5,pos:303.03},{index:10,pos:606.06},{index:15,pos:909.09}];
  evaluate(current,"aiX=fitAxisFromAi(aiVertical,16,800,'竖向');aiY=fitAxisFromAi(aiHorizontal,16,660,'横向');aiTrim=trimAiGrid({cols:16,rows:16,xOrigin:aiX.origin,yOrigin:aiY.origin,xPitch:aiX.pitch,yPitch:aiY.pitch,majorLines:{x:aiX.lines,y:aiY.lines}},{width:680,height:660})");
  assert.equal(evaluate(current,'aiTrim.cols'),16);assert.equal(evaluate(current,'aiTrim.rows'),16);assert.equal(Math.round(evaluate(current,'aiTrim.xPitch')),40);assert.equal(Math.round(evaluate(current,'aiTrim.yPitch')),40);
  assert.deepEqual(plain(evaluate(current,'axisFineBoundaries(aiX.lines,0,40,15)')), [0,40,80,120,160,200,240,280,320,360,400,440,480,520,560,600]);
  console.log('PASS: AI 5×5 major-line coordinates fit stable fine-cell cuts');
  const masks=evaluate(current,'palette.filter(p=>p._templates.length).map(p=>({mask:p._templates[0].mask,template:p._templates[0]}))');
  for(let i=0;i<120;i++){
    const actual=new Uint8Array(masks[i%masks.length].mask);actual[(i*37)%actual.length]^=1;current.actual=actual;current.template=masks[(i*13)%masks.length].template;
    const dilated=evaluate(current,'dilate(actual)'),holes=evaluate(current,'maskHoles(actual)');current.actualDilated=dilated;
    assert.equal(evaluate(current,'maskScore(actual,actualDilated,template)'),referenceScore(actual,dilated,current.template,holes));
  }
  console.log('PASS: 120 perturbed glyph masks produce exactly identical scores');
  const glyphs=plain(evaluate(current,'glyph5x7'));
  function fixture(columns,rows,pitch){
    const width=columns*pitch,height=rows*pitch,data=new Uint8Array(width*height*4),ids=['A5','F6','H7','C23','B3','C6','H12'];
    const pixel=(x,y,rgb)=>{if(x<0||y<0||x>=width||y>=height)return;const i=(y*width+x)*4;data[i]=rgb[0];data[i+1]=rgb[1];data[i+2]=rgb[2];data[i+3]=255};
    for(let y=0;y<height;y++)for(let x=0;x<width;x++)pixel(x,y,[249,250,251]);
    for(let row=1;row<rows-1;row++)for(let col=1;col<columns-1;col++){
      if((row+col)%13===0)continue;
      const color=palette.find(p=>p.id===ids[(Math.floor(row/3)+Math.floor(col/3))%ids.length]),rgb=color.rgb;
      for(let y=row*pitch+1;y<(row+1)*pitch;y++)for(let x=col*pitch+1;x<(col+1)*pitch;x++)pixel(x,y,rgb);
      const ink=(rgb[0]+rgb[1]+rgb[2])/3<120?[255,255,255]:[20,20,20],left=col*pitch+Math.floor((pitch-(color.id.length*6-1))/2),top=row*pitch+Math.floor((pitch-7)/2);
      [...color.id].forEach((letter,index)=>glyphs[letter]?.forEach((line,y)=>[...line].forEach((bit,x)=>{if(bit==='1')pixel(left+index*6+x,top+y,ink)})));
    }
    for(let y=0;y<height;y++)for(let x=0;x<width;x++)if(x%pitch===0||y%pitch===0)pixel(x,y,x%(pitch*5)===0||y%(pitch*5)===0?[30,30,30]:[180,185,190]);
    return{width,height,data,columns,rows,pitch};
  }
  async function local(context,input){
    context.fixture=input;
    evaluate(context,'image={width:fixture.width,height:fixture.height};gridModel={confirmed:true,cols:fixture.columns,rows:fixture.rows,xOrigin:0,yOrigin:0,xPitch:fixture.pitch,yPitch:fixture.pitch};prepareSourceCanvas=()=>({width:fixture.width,height:fixture.height,getContext:()=>({getImageData:()=>({data:fixture.data})})});reviewWithAi=async()=>({used:false,changed:0});renderLists=()=>{};draw=()=>{};sampleCalls=0;originalSample=sampleCell;sampleCell=(...args)=>{sampleCalls++;return originalSample(...args)}');
    const started=performance.now();await evaluate(context,'process()');
    return{ms:Math.round(performance.now()-started),calls:evaluate(context,'sampleCalls'),objects:plain(evaluate(context,'recognizedCells')),beads:evaluate(context,'beadCount')};
  }
  for(const dimensions of [[16,14,24],[11,13,20]]){
    const reference=load(process.argv[2]?path.resolve(process.argv[2]):path.join(root,'preview/index.html'));
    if(!process.argv[2]){reference.scalarScore=referenceScore;evaluate(reference,'maskScore=(actual,expanded,template)=>scalarScore(actual,expanded,{...template,holes:template.holes??maskHoles(template.mask)},actual._holes??=maskHoles(actual))')}
    const input=fixture(...dimensions),before=await local(reference,input),after=await local(load(path.join(root,'preview/index.html')),input);
    assert.deepEqual(after.objects,before.objects);assert.equal(after.beads,before.beads);assert.equal(after.calls*(process.argv[2]?2:1),before.calls);
    console.log('PASS: full local pipeline unchanged',JSON.stringify({dimensions,beads:after.beads,beforeMs:before.ms,afterMs:after.ms,beforeSamples:before.calls,afterSamples:after.calls}));
  }
  // Out-of-order AI responses must produce the same per-cell results, covering every block.
  async function aiCase(fail=false){
    const context=load(path.join(root,'preview/index.html'));let active=0,peak=0,requests=0;
    context.fetch=async(url,options)=>{
      requests++;active++;peak=Math.max(peak,active);
      try{const request=JSON.parse(options.body),prompt=request.messages[1].content[0].text,candidates=JSON.parse(prompt.split('待分析格：')[1].split('；合法')[0]);await new Promise(resolve=>setTimeout(resolve,candidates[0].sourceColumn===0?35:12));if(fail&&candidates[0].sourceRow===0&&candidates[0].sourceColumn===10)throw Error('test upstream failure');const returned=candidates.map(c=>({index:c.index,sourceRow:c.sourceRow,sourceColumn:c.sourceColumn,hasBead:true,colorId:c.index%7===0?'F6':'A5',confidence:.97,rawText:'A5',evidence:'text'}));return{ok:true,text:async()=>JSON.stringify({choices:[{message:{content:JSON.stringify({gridVersion:'test',cells:returned})}}]})}}
      finally{active--}
    };
    evaluate(context,"cols=21;rows=11;recognitionRun=1;cells=Array.from({length:cols*rows},()=>palette.find(p=>p.id==='A5'));uncertain=new Set;testMetadata=cells.map((_,index)=>({sourceRow:Math.floor(index/cols),sourceColumn:index%cols}));buildRecognizedCells(testMetadata);makeAiBlockImage=block=>'image-'+block.startRow+'-'+block.startColumn");
    const review=()=>evaluate(context,"reviewWithAi({},recognizedCells,testMetadata,{cols,rows,xOrigin:0,yOrigin:0,xPitch:24,yPitch:24},1,'test')");
    const result=await review();assert.equal(result.totalBatches,6);assert.equal(peak,2);assert.equal(active,0);assert.equal(result.failedBatches,fail?1:0);assert.equal(result.completedBatches,fail?5:6);
    const output=plain(evaluate(context,'cells.map(c=>c.id)'));output.forEach((color,index)=>{if(!(fail&&Math.floor(index/21)<10&&index%21>=10&&index%21<20))assert.equal(color,index%7===0?'F6':'A5')});
    if(!fail){evaluate(context,"cells=cells.map(()=>palette.find(p=>p.id==='A5'));uncertain=new Set;buildRecognizedCells(testMetadata)");const second=await review();assert.equal(second.cachedBatches,6);assert.equal(requests,6)}
    console.log('PASS: '+(fail?'failed block isolated; other five blocks applied':'six blocks covered with bounded concurrency; exact repeat uses cache'));
  }
  await aiCase();await aiCase(true);
}
main().catch(error=>{console.error(error);process.exitCode=1});
