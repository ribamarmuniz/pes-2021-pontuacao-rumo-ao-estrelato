const cp=require('child_process'),path=require('path'),crypto=require('crypto');
async function* readContextArchive(file,options={}){
 const args=['-NoProfile','-File',path.join(__dirname,'decode-context-archive.ps1'),'-InputFile',path.resolve(file)];
 if(options.rawFixture)args.push('-RawFixture',path.resolve(options.rawFixture));
 const child=cp.spawn('pwsh',args,{windowsHide:true,stdio:['ignore','pipe','pipe']});
 let errors='',pending=Buffer.alloc(0),finished=false;
 child.stderr.on('data',b=>{if(errors.length<65536)errors+=b.toString();});
 const completion=new Promise(resolve=>{child.on('error',error=>resolve({error}));child.on('close',(code,signal)=>{finished=true;resolve({code,signal});});});
 try{
  for await(const chunk of child.stdout){
   pending=Buffer.concat([pending,chunk]);
   while(pending.length>=16){
    if(pending.subarray(0,8).toString('ascii')!=='BALRAW3\0')throw Error('Assinatura de estado decodificado invalida');
    const length=pending.readUInt32LE(8),metaLength=pending.readUInt32LE(12);
    if(length!==0x20000||metaLength<1||metaLength>8192)throw Error('Tamanho de estado decodificado invalido');
    if(pending.length<16+length+metaLength)break;
    const meta=JSON.parse(pending.toString('utf8',16,16+metaLength)),raw=pending.subarray(16+metaLength,16+metaLength+length);
    if(meta.rawBytes!==length||meta.rawSha256!==crypto.createHash('sha256').update(raw).digest('hex'))throw Error('Integridade do estado decodificado divergente');
    pending=pending.subarray(16+metaLength+length);yield {meta,raw};
   }
  }
  const result=await completion;if(result.error||result.code!==0||result.signal)throw result.error||Error('Decodificacao falhou '+errors);
  if(pending.length)throw Error('Estado decodificado incompleto');
 }finally{if(!finished)child.kill();}
}
module.exports={readContextArchive};
