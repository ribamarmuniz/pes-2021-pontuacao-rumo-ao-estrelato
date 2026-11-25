$ErrorActionPreference='Stop'
$pesProcesses=@(Get-Process -Name PES2021 -ErrorAction Stop)
if ($pesProcesses.Count -ne 1) { throw 'O processo do PES nao e unico' }
$pesProcess=$pesProcesses[0]
if ($pesProcess.MainModule.FileName -ne 'C:\Games\PES2021\PES2021.exe') { throw 'Executavel diferente do projeto' }
$pesBase=$pesProcess.MainModule.BaseAddress.ToInt64()
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class PesEventReadOnly {
 [DllImport("kernel32",SetLastError=true)] public static extern IntPtr OpenProcess(uint access,bool inherit,int pid);
 [DllImport("kernel32",SetLastError=true)] static extern bool ReadProcessMemory(IntPtr process,IntPtr address,byte[] buffer,UIntPtr size,out UIntPtr count);
 [DllImport("kernel32")] public static extern bool CloseHandle(IntPtr handle);
 public static byte[] Read(IntPtr process,long address,int size){
  var bytes=new byte[size];UIntPtr count;
  if(!ReadProcessMemory(process,new IntPtr(address),bytes,(UIntPtr)size,out count)||count.ToUInt64()!=(ulong)size)
   throw new Exception("Falha na leitura de memoria "+Marshal.GetLastWin32Error());
  return bytes;
 }
}
'@
$pesReadHandle=[PesEventReadOnly]::OpenProcess(0x10,$false,$pesProcess.Id)
if ($pesReadHandle -eq [IntPtr]::Zero) { throw 'Acesso de leitura indisponivel' }
try {
 $pesCall=[PesEventReadOnly]::Read($pesReadHandle,$pesBase+0xa0d33e,5)
 $pesContextCall=[PesEventReadOnly]::Read($pesReadHandle,$pesBase+0xa0d30a,5)
 if ($pesCall[0] -ne 0xe8 -or $pesContextCall[0] -ne 0xe8) { throw 'Chamadas diferentes da assinatura' }
 $pesProbe=$pesBase+0xa0d33e+5+[BitConverter]::ToInt32($pesCall,1)
 $pesContextProbe=$pesBase+0xa0d30a+5+[BitConverter]::ToInt32($pesContextCall,1)
 if ($pesContextProbe -ne $pesProbe+0xa00) { throw 'As capturas nao pertencem a mesma alocacao v2' }
 $pesHeader=[PesEventReadOnly]::Read($pesReadHandle,$pesProbe+0x800,0x20)
 $pesHead=[BitConverter]::ToInt64($pesHeader,0)
 $pesSlots=@()
 for ($pesSequence=[Math]::Max(1,$pesHead-63);$pesSequence -le $pesHead;$pesSequence++) {
  $pesEntry=$pesProbe+0x1000+(($pesSequence-1)%64)*0x5000
  $pesBytes=[PesEventReadOnly]::Read($pesReadHandle,$pesEntry,128)
  $pesCheck=[PesEventReadOnly]::Read($pesReadHandle,$pesEntry,16)
  if ([BitConverter]::ToInt64($pesBytes,0) -ne $pesSequence -or [BitConverter]::ToInt64($pesBytes,8) -ne $pesSequence -or
      [Convert]::ToHexString($pesCheck) -ne [Convert]::ToHexString($pesBytes[0..15])) { continue }
  $pesSlots += [PSCustomObject]@{sequence=$pesSequence;type=[BitConverter]::ToUInt32($pesBytes,48);frame=[BitConverter]::ToUInt32($pesBytes,80)}
 }
 [PSCustomObject]@{pid=$pesProcess.Id;base=$pesBase;address=$pesProbe;head=$pesHead;enabled=($pesHeader[0x18] -eq 1);
  codeHex=[Convert]::ToHexString([PesEventReadOnly]::Read($pesReadHandle,$pesProbe,679));
  contextCodeHex=[Convert]::ToHexString([PesEventReadOnly]::Read($pesReadHandle,$pesContextProbe,700));
  slots=$pesSlots;readOnly=$true} | ConvertTo-Json -Depth 4 -Compress
} finally { [void][PesEventReadOnly]::CloseHandle($pesReadHandle) }
