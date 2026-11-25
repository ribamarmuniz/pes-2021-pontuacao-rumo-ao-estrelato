using System;
using System.IO;
using System.Runtime.InteropServices;
public static class EventContextHarness {
 [DllImport("kernel32")] static extern IntPtr VirtualAlloc(IntPtr a,UIntPtr n,uint t,uint p);
 [DllImport("kernel32")] static extern bool VirtualFree(IntPtr a,UIntPtr n,uint t);
 [DllImport("ntdll")] static extern byte RtlAddFunctionTable(IntPtr table,uint count,ulong imageBase);
 [DllImport("ntdll")] static extern byte RtlDeleteFunctionTable(IntPtr table);
 [DllImport("ntdll")] static extern IntPtr RtlVirtualUnwind(uint type,ulong imageBase,ulong pc,IntPtr entry,IntPtr context,out IntPtr handler,out ulong frame,IntPtr pointers);
 [UnmanagedFunctionPointer(CallingConvention.Winapi)] delegate ulong EventCall(IntPtr obj,IntPtr world,IntPtr input);
 static IntPtr P(long p)=>new IntPtr(p);
 static void Bytes(long p,byte[] b)=>Marshal.Copy(b,0,P(p),b.Length);
 static void Q(long p,long v)=>Marshal.WriteInt64(P(p),v);
 static void D(long p,int v)=>Marshal.WriteInt32(P(p),v);
 static long Q(long p)=>Marshal.ReadInt64(P(p));
 static int D(long p)=>Marshal.ReadInt32(P(p));
 static byte[] Read(long p,int n){var b=new byte[n];Marshal.Copy(P(p),b,0,n);return b;}
 static void Check(bool value,string label){if(!value)throw new Exception(label);}
 static bool Equal(byte[] a,byte[] b){if(a.Length!=b.Length)return false;for(int i=0;i<a.Length;i++)if(a[i]!=b[i])return false;return true;}
 public static string Run(string file,string packetFile=null){
  long game=0x140000000,a=0x144000000;
  var image=VirtualAlloc(P(game),(UIntPtr)0x4000000,0x3000,0x40);Check(image==P(game),"Imagem indisponivel");
  IntPtr buffer=IntPtr.Zero;bool registered=false;
  try{
   buffer=VirtualAlloc(P(a),(UIntPtr)0x804000,0x3000,0x40);Check(buffer==P(a),"Buffer indisponivel");
   Bytes(a,File.ReadAllBytes(file));registered=RtlAddFunctionTable(P(a+0x2840),2,(ulong)a)!=0;Check(registered,"Unwind indisponivel");
   long obj=game+0x3a00000,manager=game+0x3b00000,root=manager+0x750d0,world=game+0x3800000;
   long frame=game+0x3901000,config=game+0x37f0000,settings=game+0x37e0000,input=game+0x3900000;
   Q(obj+0xbd08,manager);D(obj+0xbd00,123);Q(game+0x36f3dc8,world);Q(world+0x2c0,settings);D(settings+0x58,BitConverter.SingleToInt32Bits(10));
   Q(a+0x3010,frame);Q(frame+520,obj);Q(frame+528,root);Q(frame+536,config);D(frame+512,44);Marshal.WriteByte(P(a+0x3018),1);
   for(int i=0;i<0x298/4;i++)D(config+i*4,BitConverter.SingleToInt32Bits(i*.125f));
   Bytes(frame+0xb4500,Read(config,0x298));
   for(int team=0;team<2;team++){
    long data=game+0x37a0000+team*0x10000,roster=game+0x37c0000+team*0x1000;
    Q(world+(team+0xa1)*40,data);Q(world+(team+0xa3)*40,roster);
    for(int i=0;i<11;i++){D(data+0x4c00+i*4,i%10);D(roster+(i+1)*4,i);}
   }
   for(int i=0;i<0x2000;i++)Marshal.WriteByte(P(root+0x108dbc+i),(byte)(i*17));
   Marshal.WriteByte(P(root+0x10acaf),2);D(root+0x108dc0,0);Marshal.WriteByte(P(root+0x108dbc+12),10);
   D(root+0x108dbc+44,1);Marshal.WriteByte(P(root+0x108dbc+52),20);
   for(int i=0;i<0x320;i++)Marshal.WriteByte(P(input+i),(byte)(i*13));D(input,24);
   for(int index=0;index<80;index++){
    long record=root+0x64d8+(index/40)*0x59650+(index%40)*0x2134;
    D(record+4,index==57?unchecked((int)0x800000ba):1000+index);
    Marshal.WriteInt16(P(record+0x18ec),(short)((30<<8)|(index%3==0&&index!=57?255:0)));
    D(record+0x1934,BitConverter.SingleToInt32Bits(6.5f));
    for(int id=0;id<135;id++)for(int period=0;period<8;period++)D(record+8+id*36+period*4,index*10000+id*10+period);
    for(int role=0;role<13;role++)D(record+0x18fc+role*4,index+role);
    for(int j=0;j<4;j++){D(manager+0x180760+index*16+j*4,index*4+j);D(obj+0x1c0+index*16+j*4,index*16+j);}
   }
   long target=root+0x64d8+0x59650+17*0x2134,other=root+0x64d8+4*0x2134,unique=manager+0x180760+57*16;
   byte[] Callback(long record,int displacement){
    var b=new System.Collections.Generic.List<byte>(Convert.FromHexString("49ba"));b.AddRange(BitConverter.GetBytes(record));
    b.AddRange(Convert.FromHexString("41ff82"));b.AddRange(BitConverter.GetBytes(displacement));
    b.AddRange(Convert.FromHexString("49ba"));b.AddRange(BitConverter.GetBytes(other));b.AddRange(Convert.FromHexString("41ff8220030000"));
    b.AddRange(Convert.FromHexString("49ba"));b.AddRange(BitConverter.GetBytes(unique));b.AddRange(Convert.FromHexString("41ff420448b88877665544332211c3"));return b.ToArray();
   }
   Bytes(game+0xa22130,Callback(target,8));Bytes(game+0xa23c10,Callback(target,0x680));
   var call=Marshal.GetDelegateForFunctionPointer<EventCall>(P(a));var contextCall=Marshal.GetDelegateForFunctionPointer<EventCall>(P(a+0x1000));
   for(int pass=0;pass<2;pass++){
    var records=new byte[80][];for(int i=0;i<80;i++)records[i]=Read(root+0x64d8+(i/40)*0x59650+(i%40)*0x2134,0x2134);
    var uniqueBefore=Read(manager+0x180760,80*16);
    Check((pass==0?call(P(obj),IntPtr.Zero,P(input)):contextCall(P(obj),IntPtr.Zero,P(1)))==0x1122334455667788UL,"Retorno alterado");
    long entry=a+0x4000+pass*0x20000;Check(Q(entry)==pass+1&&Q(entry+8)==pass+1,"Sequencia incorreta");
    Check(D(entry+0x58)==0&&Q(a+0x3020)==0,"Marcador de sobreposicao incorreto");
    for(int phase=0;phase<2;phase++){
     long state=entry+(phase==0?0x1000:0x10000);
     Check(D(state+0xec00)==1&&D(state+0xec04)==BitConverter.SingleToInt32Bits(10),"Cabecalho invalido");
     Check(Q(state+0xec08)==root&&Q(state+0xec10)==obj&&D(state+0xec18)==123&&D(state+0xec1c)==123,"Origem ou frame incorreto");
     Check(D(state+0xec28)==44&&D(state+0xec2c)==44,"Geracao incorreta");
     Check(Equal(Read(state+0xc800,0x298),Read(config,0x298)),"Configuracao incorreta");
     Check(Equal(Read(state+0xcc00,0x2000),Read(root+0x108dbc,0x2000)),"Gols incorretos");
     for(int team=0;team<2;team++){
      Check(Equal(Read(state+0xcb00+team*128,44),Read(Q(world+(team+0xa1)*40)+0x4c00,44)),"Categorias incorretas");
      Check(Equal(Read(state+0xcb2c+team*128,48),Read(Q(world+(team+0xa3)*40),48)),"Escalacao incorreta");
     }
     for(int index=0;index<80;index++){
      long record=root+0x64d8+(index/40)*0x59650+(index%40)*0x2134,row=state+index*0x280;
      var original=phase==0?records[index]:Read(record,0x2134);
      Check(D(row)==BitConverter.ToInt32(original,4)&&Marshal.ReadInt16(P(row+4))==BitConverter.ToInt16(original,0x18ec),"Identidade incorreta");
      Check(Equal(Read(row+8,16),Read(obj+0x1c0+index*16,16))&&D(row+0x18)==BitConverter.ToInt32(original,0x1934),"Engine incorreto");
      for(int id=0;id<135;id++){
       uint sum=0;for(int period=0;period<8;period++)sum+=BitConverter.ToUInt32(original,8+id*36+period*4);
       Check(unchecked((uint)D(row+0x20+id*4))==sum,"Soma incorreta no jogador "+index+" estatistica "+id);
      }
      Check(Equal(Read(row+0x23c,16),phase==0?uniqueBefore[(index*16)..(index*16+16)]:Read(manager+0x180760+index*16,16)),"Exclusivos incorretos");
      Check(Equal(Read(row+0x24c,52),original[0x18fc..0x1930]),"Posicoes incorretas");
     }
    }
    if(pass==0&&!String.IsNullOrEmpty(packetFile))File.WriteAllBytes(packetFile,Read(entry,0x20000));
   }
   long Latest(){long seq=Q(a+0x3000);return a+0x4000+((seq-1)%64)*0x20000;}
   for(int i=0;i<65;i++){
    Check(call(P(obj),IntPtr.Zero,P(input))==0x1122334455667788UL,"Retorno no ciclo alterado");
    long entry=Latest();Check(Q(entry)==i+3&&Q(entry+8)==i+3&&D(entry+0x1000+0xec00)==1&&D(entry+0x10000+0xec00)==1,"Ciclo de buffer incorreto");
   }
   Q(a+0x3010,0);call(P(obj),IntPtr.Zero,P(input));
   Check(D(Latest()+0x1000+0xec00)==0&&D(Latest()+0x10000+0xec00)==0,"Configuracao ausente deveria invalidar os estados");Q(a+0x3010,frame);
   Q(frame+528,root+8);call(P(obj),IntPtr.Zero,P(input));
   Check(D(Latest()+0x1000+0xec00)==0,"Configuracao de outra raiz deveria ser rejeitada");Q(frame+528,root);
   Q(game+0x36f3dc8,0);call(P(obj),IntPtr.Zero,P(input));
   Check(D(Latest()+0x1000+0xec00)==0,"Mundo ausente deveria ser rejeitado");Q(game+0x36f3dc8,world);
   Q(a+0x3020,1);call(P(obj),IntPtr.Zero,P(input));
   Check(D(Latest()+0x58)==1&&Q(a+0x3020)==1,"Sobreposicao deveria ser sinalizada sem consumir o outro escritor");Q(a+0x3020,0);
   var generationNative=new System.Collections.Generic.List<byte>(Convert.FromHexString("49ba"));
   generationNative.AddRange(BitConverter.GetBytes(frame));generationNative.AddRange(Convert.FromHexString("41ff820002000048b88877665544332211c3"));
   Bytes(game+0xa22130,generationNative.ToArray());call(P(obj),IntPtr.Zero,P(input));
   Check(D(Latest()+0x1000+0xec00)==1&&D(Latest()+0x10000+0xec00)==0,"Geracao impar deveria invalidar a copia posterior");D(frame+512,44);
   var rootNative=new System.Collections.Generic.List<byte>(Convert.FromHexString("49ba"));
   rootNative.AddRange(BitConverter.GetBytes(obj));rootNative.AddRange(Convert.FromHexString("49c78208bd00000000000048b88877665544332211c3"));
   Bytes(game+0xa22130,rootNative.ToArray());call(P(obj),IntPtr.Zero,P(input));
   Check(D(Latest()+0x1000+0xec00)==1&&D(Latest()+0x10000+0xec00)==0,"Mudanca de raiz deveria impedir a leitura antiga");
   long countBefore=Q(a+0x3000);call(P(obj),IntPtr.Zero,P(input));Check(Q(a+0x3000)==countBefore,"Manager ausente deveria suprimir somente a captura");Q(obj+0xbd08,manager);
   long ctx=game+0x38e0000,sp=game+0x38f0000;IntPtr handler;ulong establisher;
   foreach(int offset in new int[]{0,0x1000}){
    Q(ctx+152,sp);Q(ctx+248,a+offset+200);Q(sp+0x70,111);Q(sp+0x78,222);Q(sp+0xb0,333);Q(sp+0xb8,444);
    RtlVirtualUnwind(0,(ulong)a,(ulong)(a+offset+200),P(a+0x2840+(offset==0?0:12)),P(ctx),out handler,out establisher,IntPtr.Zero);
    Check(Q(ctx+152)==sp+0xc0&&Q(ctx+248)==444&&Q(ctx+216)==333&&Q(ctx+168)==111&&Q(ctx+176)==222,"Unwind incorreto");
   }
   return "{\"passed\":true,\"synthetic\":true,\"capturedCalls\":73,\"rowsCompared\":320,\"statSumsCompared\":43200,\"otherPlayerChangeCaptured\":true,\"ringWrapVerified\":true,\"missingConfigurationRejected\":true,\"wrongRootConfigurationRejected\":true,\"missingWorldRejected\":true,\"overlapMarked\":true,\"oddGenerationRejected\":true,\"changedRootRejected\":true,\"missingManagerVerified\":true,\"windowsUnwindVerified\":true}";
  }finally{if(registered)RtlDeleteFunctionTable(P(a+0x2840));if(buffer!=IntPtr.Zero)VirtualFree(buffer,UIntPtr.Zero,0x8000);VirtualFree(image,UIntPtr.Zero,0x8000);}
 }
}
