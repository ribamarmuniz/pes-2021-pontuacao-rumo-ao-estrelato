using System;
using System.IO;
using System.Collections.Generic;
using System.Runtime.InteropServices;

// Runs copied PES arithmetic in THIS short-lived study process only.
// No OpenProcess, remote memory access, injection, save editing or game writes.
public static class NativeNormalizer {
 [DllImport("kernel32",SetLastError=true)] static extern IntPtr VirtualAlloc(IntPtr address,UIntPtr size,uint type,uint protection);
 [DllImport("kernel32")] static extern bool VirtualFree(IntPtr address,UIntPtr size,uint type);
 [DllImport("kernel32")] static extern bool FlushInstructionCache(IntPtr process,IntPtr address,UIntPtr size);
 [DllImport("kernel32")] static extern IntPtr GetCurrentProcess();
 [UnmanagedFunctionPointer(CallingConvention.Winapi)] delegate void NormalizeFn(IntPtr scratch,IntPtr root,IntPtr unused);
 [UnmanagedFunctionPointer(CallingConvention.Winapi)] delegate float RawFn(IntPtr context,int player,IntPtr program);
 const long ImageBase=0x140000000;
 static IntPtr P(long address){return new IntPtr(address);}
 static IntPtr Alloc(int size){var p=VirtualAlloc(IntPtr.Zero,(UIntPtr)size,0x3000,4);if(p==IntPtr.Zero)throw new Exception("VirtualAlloc failed");return p;}
 static void Put(IntPtr p,int offset,byte[] bytes){Marshal.Copy(bytes,0,IntPtr.Add(p,offset),bytes.Length);}
 static void F(IntPtr p,int offset,float v){Marshal.WriteInt32(p,offset,BitConverter.SingleToInt32Bits(v));}
 static float GetF(IntPtr p,int offset){return BitConverter.Int32BitsToSingle(Marshal.ReadInt32(p,offset));}
 static void Stub(int rva,byte[] bytes){Marshal.Copy(bytes,0,P(ImageBase+rva),bytes.Length);}
 public static int Run(string game,string input,string output,bool rawMode=false){
  var allocations=new List<IntPtr>();
  var image=VirtualAlloc(P(ImageBase),(UIntPtr)0x4000000,0x3000,0x40);
  if(image!=P(ImageBase)){if(image!=IntPtr.Zero)VirtualFree(image,UIntPtr.Zero,0x8000);throw new Exception("Study image address unavailable");}
  allocations.Add(image);
  try{
   using(var f=File.OpenRead(game))using(var r=new BinaryReader(f)){
    f.Position=60;int pe=r.ReadInt32();f.Position=pe+6;int count=r.ReadUInt16();f.Position=pe+20;int opt=r.ReadUInt16();
    for(int i=0;i<count;i++){
     f.Position=pe+24+opt+i*40;string name=System.Text.Encoding.ASCII.GetString(r.ReadBytes(8)).TrimEnd('\0');
     r.ReadInt32();int rva=r.ReadInt32(),size=r.ReadInt32(),raw=r.ReadInt32();
     if(name!=".trace"&&name!=".rdata"&&name!=".data")continue;
     if(rva<0||size<0||(long)rva+size>0x4000000)throw new Exception("Unexpected section bounds");
     f.Position=raw;byte[] data=r.ReadBytes(size);if(data.Length!=size)throw new Exception("Truncated section");Put(image,rva,data);
    }
   }
   byte[] signature={0x48,0x8b,0xc4,0x55,0x56,0x57,0x41,0x54};
   for(int i=0;i<signature.Length;i++)if(Marshal.ReadByte(image,0xa1d300+i)!=signature[i])throw new Exception("Normalizer signature differs");
   var root=Alloc(0xc0000);allocations.Add(root);
   var obj=Alloc(0x1000);allocations.Add(obj);
   var config=Alloc(0x1000);allocations.Add(config);
   var world=Alloc(0x1000);allocations.Add(world);
   var settings=Alloc(0x1000);allocations.Add(settings);
   var arguments=Alloc(0x1000);allocations.Add(arguments);
   var program=Alloc(0x1000);allocations.Add(program);
   Marshal.WriteInt64(image,0x36f3dc8,world.ToInt64());Marshal.WriteInt64(world,0x2c0,settings.ToInt64());
   // Configuration/container adapters only. Original normalizer arithmetic,
   // player lookup, stat summation and role lookup remain byte-for-byte PES code.
   Stub(0x14dab90,new byte[]{0xc3});Stub(0x1794410,new byte[]{0xc3});Stub(0x159f3e0,new byte[]{0xc3});
   byte[] getConfig=new byte[11];getConfig[0]=0x48;getConfig[1]=0xb8;BitConverter.GetBytes(config.ToInt64()).CopyTo(getConfig,2);getConfig[10]=0xc3;Stub(0x1e5d4c0,getConfig);
   Stub(0x15a1720,new byte[]{0x57,0x49,0x89,0xc9,0x48,0x89,0xcf,0x89,0xd0,0x4c,0x89,0xc1,0xfc,0xf3,0xaa,0x4c,0x89,0xc8,0x5f,0xc3});
   // This getter is used only with score selector 5 inside this normalizer.
   // Read the supplied collective score from each synthetic team header.
   Stub(0x8c9df0,new byte[]{0x0f,0xb6,0x01,0xc3});
   if(rawMode){
    for(int id=0;id<92;id++){
     // Supply the recorded getter result. The original expression interpreter
     // and its arithmetic operators are executed without changes.
     var code=new List<byte>(new byte[]{0x48,0xb8});code.AddRange(BitConverter.GetBytes(arguments.ToInt64()+id*4));
     code.AddRange(new byte[]{0xf3,0x0f,0x10,0x00,0xf3,0x0f,0x11,0x41,0x04,0xc7,0x01,1,0,0,0,0xb0,1,0xc3});
     int site=0x3a00000+id*64;Stub(site,code.ToArray());Marshal.WriteInt64(image,0x25d4408+id*16,ImageBase+site);
    }
   }
   FlushInstructionCache(GetCurrentProcess(),image,(UIntPtr)0x4000000);
   var normalize=Marshal.GetDelegateForFunctionPointer<NormalizeFn>(P(ImageBase+0xa1d300));
   var rawFn=Marshal.GetDelegateForFunctionPointer<RawFn>(P(ImageBase+0x6a49e0));
   byte[] emptyRoot=new byte[0xc0000],emptyObject=new byte[0x1000];
   using(var f=File.OpenRead(input))using(var r=new BinaryReader(f))using(var w=new BinaryWriter(File.Create(output))){
    int cases=r.ReadInt32();if(cases<1||cases>100000)throw new Exception("Invalid case count");w.Write(cases);
    for(int c=0;c<cases;c++){
     if(rawMode){
      int length=r.ReadInt32();if(length<12||length>0xc00||length%12!=0)throw new Exception("Invalid expression length");
      byte[] bytes=r.ReadBytes(length);if(bytes.Length!=length)throw new Exception("Truncated expression");
      Put(program,0,bytes);Marshal.WriteInt32(program,0xc00,length/12);
      for(int id=0;id<92;id++)F(arguments,id*4,r.ReadSingle());
      w.Write(rawFn(IntPtr.Zero,0,program));continue;
     }
     Put(root,0,emptyRoot);Put(obj,0,emptyObject);
     int n=r.ReadInt32();if(n<1||n>80)throw new Exception("Invalid player count");
     float duration=r.ReadSingle();int score0=r.ReadInt32(),score1=r.ReadInt32();
     Marshal.WriteByte(root,0,(byte)score0);Marshal.WriteByte(root,0x59650,(byte)score1);F(settings,0x58,duration);
     for(int i=0;i<0x298/4;i++)F(config,i*4,r.ReadSingle());
     for(int team=0;team<2;team++)for(int slot=0;slot<40;slot++)Marshal.WriteByte(root,team*0x59650+0x64d8+slot*0x2134+0x18ec,255);
     int[] slots=new int[n];
     for(int i=0;i<n;i++){
      double[] v=new double[12];for(int j=0;j<12;j++)v[j]=r.ReadDouble();
      int team=(int)v[0],slot=(int)v[1];if(team<0||team>1||slot<0||slot>=40)throw new Exception("Invalid player slot");
      int record=team*0x59650+0x64d8+slot*0x2134,index=team*40+slot;slots[i]=index;
      Marshal.WriteByte(root,record+0x18ec,(byte)v[3]);Marshal.WriteByte(root,record+0x18ed,(byte)v[4]);
      if(v[5]>=0&&v[5]<13)Marshal.WriteInt32(root,record+0x18fc+(int)v[5]*4,1);
      F(obj,0x1c0+index*16,(float)v[6]);
      Marshal.WriteInt32(obj,0x1c8+index*16,unchecked((int)(uint)v[9]));Marshal.WriteInt32(obj,0x1cc+index*16,unchecked((int)(uint)v[10]));
      for(int j=0;j<135;j++)Marshal.WriteInt32(root,record+8+j*36,unchecked((int)r.ReadUInt32()));
     }
     normalize(obj,root,IntPtr.Zero);
     w.Write(n);for(int i=0;i<n;i++)w.Write(GetF(obj,0x1c4+slots[i]*16));
    }
    if(f.Position!=f.Length)throw new Exception("Trailing input bytes");
   }
   GC.KeepAlive(normalize);GC.KeepAlive(rawFn);return 0;
  }finally{foreach(var a in allocations)VirtualFree(a,UIntPtr.Zero,0x8000);}
 }
}
