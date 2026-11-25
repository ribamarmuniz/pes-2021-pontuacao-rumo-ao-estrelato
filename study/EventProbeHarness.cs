using System;
using System.IO;
using System.Runtime.InteropServices;
public static class EventProbeHarness {
 [DllImport("kernel32")] static extern IntPtr VirtualAlloc(IntPtr a,UIntPtr n,uint t,uint p);
 [DllImport("kernel32")] static extern bool VirtualFree(IntPtr a,UIntPtr n,uint t);
 [DllImport("ntdll")] static extern byte RtlAddFunctionTable(IntPtr table,uint count,ulong imageBase);
 [DllImport("ntdll")] static extern byte RtlDeleteFunctionTable(IntPtr table);
 [DllImport("ntdll")] static extern IntPtr RtlVirtualUnwind(uint type,ulong imageBase,ulong pc,IntPtr entry,IntPtr context,out IntPtr handler,out ulong frame,IntPtr pointers);
 [UnmanagedFunctionPointer(CallingConvention.Winapi)] delegate ulong EventCall(IntPtr obj,IntPtr world,IntPtr input);
 static IntPtr P(long x)=>new IntPtr(x);
 static void Bytes(long p,byte[] b)=>Marshal.Copy(b,0,P(p),b.Length);
 static void U64(long p,long v)=>Marshal.WriteInt64(P(p),v);
 static void U32(long p,int v)=>Marshal.WriteInt32(P(p),v);
 static long Q(long p)=>Marshal.ReadInt64(P(p));
 static int D(long p)=>Marshal.ReadInt32(P(p));
 static byte[] Read(long p,int n){var b=new byte[n];Marshal.Copy(P(p),b,0,n);return b;}
 static bool Equal(byte[] a,byte[] b){if(a.Length!=b.Length)return false;for(int i=0;i<a.Length;i++)if(a[i]!=b[i])return false;return true;}
 static void Check(bool value,string message){if(!value)throw new Exception(message);}
 public static string Run(string codeFile){
  long game=0x140000000,probe=0x144000000;
  IntPtr image=VirtualAlloc(P(game),(UIntPtr)0x4000000,0x3000,0x40);
  if(image!=P(game))throw new Exception("Endereco de ensaio indisponivel");
  IntPtr buffer=IntPtr.Zero;bool registered=false;
  try{
   buffer=VirtualAlloc(P(probe),(UIntPtr)0x141000,0x3000,0x40);
   Check(buffer==P(probe),"Buffer de ensaio indisponivel");
   Bytes(probe,File.ReadAllBytes(codeFile));
   registered=RtlAddFunctionTable(P(probe+0x920),2,(ulong)probe)!=0;
   Check(registered,"Registro de unwind indisponivel");
   Marshal.WriteByte(P(probe+0x818),1);
   long obj=game+0x3a00000,manager=game+0x3b00000,root=manager+0x750d0;
   long input=game+0x3900000,frame=game+0x3901000;
   int slot=57;
   long record=root+0x64d8+0x59650+(slot-40)*0x2134,unique=manager+0x180760+slot*16;
   U64(obj+0xbd08,manager);U32(obj+0xbd00,123);U32(record+4,unchecked((int)0x800000ba));
   U32(record+8,2);U32(record+8+6*36,3);U32(unique+4,7);
   for(int i=0;i<0x320;i++)Marshal.WriteByte(P(input+i),(byte)(i*13));
   U32(input,12);U64(probe+0x810,frame);U32(frame+512,44);
   // Synthetic ABI-conforming callee. It changes exactly two counters and one unique.
   // It also exercises shadow space and records its incoming stack alignment.
   var native=new System.Collections.Generic.List<byte>();
   void Hex(string hex){native.AddRange(Convert.FromHexString(hex));}
   void Pointer(long p){native.AddRange(BitConverter.GetBytes(p));}
   Hex("49ba");Pointer(record);Hex("41ff420841ff82e0000000");
   Hex("49ba");Pointer(unique);Hex("41ff4204");
   Hex("488bc44883e00f49ba");Pointer(frame+520);Hex("418902");
   Hex("48b831425364758697a8488944240848b88877665544332211c3");
   Bytes(game+0xa22130,native.ToArray());
   var invoke=Marshal.GetDelegateForFunctionPointer<EventCall>(P(probe));
   int captures=0;
   for(int call=0;call<70;call++){
    var before=Read(record,0x2134);var beforeUnique=Read(unique,16);
    ulong result=invoke(P(obj),IntPtr.Zero,P(input));
    Check(result==0x1122334455667788UL,"Retorno original alterado");
    Check(D(frame+520)==8,"Alinhamento incorreto na chamada original");
    long seq=call+1,entry=probe+0x1000+(call%64)*0x5000;
    Check(Q(entry)==seq&&Q(entry+8)==seq,"Publicacao incompleta");
    Check(Q(entry+16)==root&&Q(entry+24)==record&&Q(entry+32)==obj,"Ponteiros incorretos");
    Check(D(entry+48)==12&&D(entry+52)==slot&&Q(entry+56)>0,"Metadados incorretos");
    Check(D(entry+64)==44&&D(entry+68)==44&&D(entry+80)==123,"Marcadores incorretos");
    Check(Equal(Read(entry+0x180,0x320),Read(input,0x320)),"Evento incorreto");
    Check(Equal(Read(entry+0x500,0x2134),before),"Copia anterior incorreta");
    Check(Equal(Read(entry+0x2800,0x2134),Read(record,0x2134)),"Copia posterior incorreta");
    Check(Equal(Read(entry+0x100,16),beforeUnique)&&Equal(Read(entry+0x110,16),Read(unique,16)),"Exclusivos incorretos");
    captures++;
   }
   U32(record+4,0);invoke(P(obj),IntPtr.Zero,P(input));
   Check(Q(probe+0x800)==70,"Ausencia do jogador deveria suprimir apenas a captura");
   Check(D(record+8)==73,"Chamada original omitida sem jogador selecionado");
   U32(record+4,unchecked((int)0x800000ba));
   Marshal.WriteByte(P(probe+0x818),0);invoke(P(obj),IntPtr.Zero,P(input));
   Check(Q(probe+0x800)==70&&D(record+8)==74,"Desativacao alterou a chamada original");
   Marshal.WriteByte(P(probe+0x818),1);U64(probe+0x810,0);U32(record+4,0);
   foreach(int selected in new int[]{0,10,39,40,79}){
    record=root+0x64d8+(selected/40)*0x59650+(selected%40)*0x2134;
    unique=manager+0x180760+selected*16;
    U32(record+4,unchecked((int)0x800000ba));U32(record+8,5);
    Bytes(game+0xa22130+2,BitConverter.GetBytes(record));
    Bytes(game+0xa22130+23,BitConverter.GetBytes(unique));
    var before=Read(record,0x2134);invoke(P(obj),IntPtr.Zero,P(input));
    long seq=Q(probe+0x800),entry=probe+0x1000+((seq-1)%64)*0x5000;
    Check(D(entry+52)==selected&&Q(entry+24)==record&&Q(entry+8)==seq,"Selecao de slot incorreta");
    Check(D(entry+64)==0&&D(entry+68)==0,"Marcador ausente conservou geracao antiga");
    Check(Equal(Read(entry+0x500,0x2134),before)&&Equal(Read(entry+0x2800,0x2134),Read(record,0x2134)),"Copia de outro slot incorreta");
    U32(record+4,0);captures++;
   }
   U32(record+4,unchecked((int)0x800000ba));
   var contextNative=new System.Collections.Generic.List<byte>(Convert.FromHexString("49ba"));
   contextNative.AddRange(BitConverter.GetBytes(record));
   contextNative.AddRange(Convert.FromHexString("41ff828006000048b88877665544332211c3"));
   Bytes(game+0xa23c10,contextNative.ToArray());
   var contextCall=Marshal.GetDelegateForFunctionPointer<EventCall>(P(probe+0xa00));
   var contextBefore=Read(record,0x2134);
   Check(contextCall(P(obj),IntPtr.Zero,P(1))==0x1122334455667788UL,"Retorno de contexto alterado");
   long contextSequence=Q(probe+0x800),contextEntry=probe+0x1000+((contextSequence-1)%64)*0x5000;
   Check(D(contextEntry+48)==-2&&Q(contextEntry+40)==0&&Q(contextEntry+8)==contextSequence,"Metadados de contexto incorretos");
   var contextPayload=Read(contextEntry+0x180,0x320);
   Check(BitConverter.ToInt32(contextPayload,0)==-2,"Tipo de contexto incorreto");
   for(int i=4;i<contextPayload.Length;i++)Check(contextPayload[i]==0,"Payload de contexto conservou dados antigos");
   Check(Equal(Read(contextEntry+0x500,0x2134),contextBefore)&&Equal(Read(contextEntry+0x2800,0x2134),Read(record,0x2134)),"Copia de contexto incorreta");captures++;
   long context=game+0x38e0000,sp=game+0x38f0000;
   U64(context+152,sp);U64(context+248,probe+200);
   U64(sp+0x70,111);U64(sp+0x78,222);U64(sp+0xb0,333);U64(sp+0xb8,444);
   IntPtr handler;ulong establisher;
   RtlVirtualUnwind(0,(ulong)probe,(ulong)(probe+200),P(probe+0x920),P(context),out handler,out establisher,IntPtr.Zero);
   Check(Q(context+152)==sp+0xc0&&Q(context+248)==444&&Q(context+216)==333,"Unwind da pilha ou R12 incorreto");
   Check(Q(context+168)==111&&Q(context+176)==222,"Unwind de RSI/RDI incorreto");
   U64(context+152,sp);U64(context+248,probe+0xa00+200);
   RtlVirtualUnwind(0,(ulong)probe,(ulong)(probe+0xa00+200),P(probe+0x92c),P(context),out handler,out establisher,IntPtr.Zero);
   Check(Q(context+152)==sp+0xc0&&Q(context+248)==444&&Q(context+216)==333&&Q(context+168)==111&&Q(context+176)==222,"Unwind de contexto incorreto");
   return "{\"passed\":true,\"synthetic\":true,\"capturedCalls\":"+captures+",\"ringWrapVerified\":true,\"absentPlayerVerified\":true,\"disabledCollectorVerified\":true,\"slotsVerified\":[0,10,39,40,57,79],\"missingGenerationPointerVerified\":true,\"contextCallWithoutEventPointerVerified\":true,\"windowsUnwindVerified\":true}";
  }finally{if(registered)RtlDeleteFunctionTable(P(probe+0x920));if(buffer!=IntPtr.Zero)VirtualFree(buffer,UIntPtr.Zero,0x8000);VirtualFree(image,UIntPtr.Zero,0x8000);}
 }
}
