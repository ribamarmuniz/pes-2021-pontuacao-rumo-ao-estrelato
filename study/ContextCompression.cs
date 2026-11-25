using System;
using System.Runtime.InteropServices;
public static class ContextCompression {
 [DllImport("cabinet",SetLastError=true)] static extern bool CreateCompressor(uint algorithm,IntPtr allocation,out IntPtr handle);
 [DllImport("cabinet",SetLastError=true)] static extern bool CreateDecompressor(uint algorithm,IntPtr allocation,out IntPtr handle);
 [DllImport("cabinet",SetLastError=true)] static extern bool Compress(IntPtr handle,byte[] source,UIntPtr sourceSize,byte[] output,UIntPtr outputSize,out UIntPtr written);
 [DllImport("cabinet",SetLastError=true)] static extern bool Decompress(IntPtr handle,byte[] source,UIntPtr sourceSize,byte[] output,UIntPtr outputSize,out UIntPtr written);
 [DllImport("cabinet")] static extern bool CloseCompressor(IntPtr handle);
 [DllImport("cabinet")] static extern bool CloseDecompressor(IntPtr handle);
 public static byte[] Encode(byte[] source){
  IntPtr handle;if(!CreateCompressor(4,IntPtr.Zero,out handle))throw new Exception("CreateCompressor "+Marshal.GetLastWin32Error());
  try{
   var output=new byte[source.Length*2+4096];UIntPtr used;
   if(!Compress(handle,source,(UIntPtr)source.Length,output,(UIntPtr)output.Length,out used))throw new Exception("Compress "+Marshal.GetLastWin32Error());
   Array.Resize(ref output,checked((int)used.ToUInt64()));return output;
  }finally{CloseCompressor(handle);}
 }
 public static byte[] Decode(byte[] source,int expectedSize){
  if(expectedSize<1||expectedSize>0x20000)throw new Exception("Tamanho de estado invalido");
  IntPtr handle;if(!CreateDecompressor(4,IntPtr.Zero,out handle))throw new Exception("CreateDecompressor "+Marshal.GetLastWin32Error());
  try{
   var output=new byte[expectedSize];UIntPtr used;
   if(!Decompress(handle,source,(UIntPtr)source.Length,output,(UIntPtr)output.Length,out used)||used.ToUInt64()!=(ulong)expectedSize)
    throw new Exception("Decompress "+Marshal.GetLastWin32Error());return output;
  }finally{CloseDecompressor(handle);}
 }
 public static string Selftest(){
  long input=0,compressed=0;
  foreach(int size in new int[]{1,1024,0x20000})foreach(bool patterned in new bool[]{false,true}){
   var bytes=new byte[size];var random=new Random(1741+size);random.NextBytes(bytes);
   if(patterned)for(int i=0;i<size;i++)bytes[i]=(byte)(i%27==0?i:0);
   var packed=Encode(bytes);var decoded=Decode(packed,size);
   for(int i=0;i<size;i++)if(decoded[i]!=bytes[i])throw new Exception("Roundtrip diferente");
   input+=size;compressed+=packed.Length;
  }
  return "{\"passed\":true,\"cases\":6,\"sourceBytes\":"+input+",\"compressedBytes\":"+compressed+",\"lossless\":true,\"algorithm\":\"XPRESS_HUFF-buffer-mode\"}";
 }
}
