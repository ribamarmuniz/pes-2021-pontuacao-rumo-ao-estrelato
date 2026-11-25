using System;
using System.IO;
using System.Text;
using System.Security.Cryptography;
public static class ContextArchive {
 static readonly byte[] CompressedMagic=Encoding.ASCII.GetBytes("BALCTX3\0"),RawMagic=Encoding.ASCII.GetBytes("BALRAW3\0");
 static bool Equal(byte[] a,byte[] b){if(a.Length!=b.Length)return false;for(int i=0;i<a.Length;i++)if(a[i]!=b[i])return false;return true;}
 public static void WriteFixture(string rawFile,string archive){
  var raw=File.ReadAllBytes(rawFile);if(raw.Length!=0x20000)throw new Exception("Pacote sintetico de tamanho diferente");
  string hash;using(var algorithm=SHA256.Create())hash=Convert.ToHexString(algorithm.ComputeHash(raw)).ToLowerInvariant();
  byte[] compressed=ContextCompression.Encode(raw),meta=Encoding.UTF8.GetBytes("{\"synthetic\":true,\"session\":\"selftest\",\"epoch\":1,\"rawBytes\":131072,\"rawSha256\":\""+hash+"\"}");
  using(var file=new FileStream(archive,FileMode.CreateNew))using(var w=new BinaryWriter(file)){
   w.Write(CompressedMagic);w.Write(compressed.Length);w.Write(meta.Length);w.Write(meta);w.Write(compressed);
  }
 }
 public static void TranscodeToStdout(string archive){
  using(var file=new FileStream(archive,FileMode.Open,FileAccess.Read,FileShare.ReadWrite))using(var r=new BinaryReader(file)){
   long snapshotLength=file.Length;var output=Console.OpenStandardOutput();
   using(var w=new BinaryWriter(output,Encoding.UTF8,true))while(file.Position<snapshotLength){
    if(snapshotLength-file.Position<16)break;
    if(!Equal(r.ReadBytes(8),CompressedMagic))throw new Exception("Assinatura de pacote invalida");
    int count=r.ReadInt32(),metadataLength=r.ReadInt32();
    if(count<1||count>0x40000||metadataLength<1||metadataLength>8192)throw new Exception("Tamanho de pacote invalido");
    if(snapshotLength-file.Position<(long)count+metadataLength)break;
    byte[] metadata=r.ReadBytes(metadataLength),packed=r.ReadBytes(count),raw=ContextCompression.Decode(packed,0x20000);
    w.Write(RawMagic);w.Write(raw.Length);w.Write(metadata.Length);w.Write(metadata);w.Write(raw);
   }
  }
 }
}
