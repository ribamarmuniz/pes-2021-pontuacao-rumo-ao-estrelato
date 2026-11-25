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
 $pesSite=$pesBase+0xa0d33e
 $pesCall=[PesEventReadOnly]::Read($pesReadHandle,$pesSite,5)
 if ($pesCall[0] -ne 0xe8) { throw 'Chamada diferente' }
 $pesFull=$pesSite+5+[BitConverter]::ToInt32($pesCall,1)
 $pesCode=[PesEventReadOnly]::Read($pesReadHandle,$pesFull,2220)
 if ($pesCode[1223] -ne 0xe8) { throw 'Wrapper diferente do layout validado' }
 $pesLegacy=$pesFull+1228+[BitConverter]::ToInt32($pesCode,1224)
 $pesContextCall=[PesEventReadOnly]::Read($pesReadHandle,$pesBase+0xa0d30a,5)
 if ($pesContextCall[0] -ne 0xe8 -or $pesBase+0xa0d30a+5+[BitConverter]::ToInt32($pesContextCall,1) -ne $pesLegacy+0xa00) { throw 'Cadeia diferente da v2 validada' }
 $pesHeader=[PesEventReadOnly]::Read($pesReadHandle,$pesFull+0x3000,0x30)
 $pesHead=[BitConverter]::ToInt64($pesHeader,0)
 $pesSlots=@()
 for ($pesSequence=[Math]::Max(1,$pesHead-63);$pesSequence -le $pesHead;$pesSequence++) {
  $pesAt=$pesFull+0x4000+(($pesSequence-1)%64)*0x20000
  $pesSlot=[PesEventReadOnly]::Read($pesReadHandle,$pesAt,128)
  $pesCheck=[PesEventReadOnly]::Read($pesReadHandle,$pesAt,16)
  if ([BitConverter]::ToInt64($pesSlot,0) -eq $pesSequence -and [BitConverter]::ToInt64($pesSlot,8) -eq $pesSequence -and [Convert]::ToHexString($pesCheck) -eq [Convert]::ToHexString($pesSlot[0..15])) {
   $pesSlots += [PSCustomObject]@{sequence=$pesSequence;type=[BitConverter]::ToUInt32($pesSlot,48);generationBefore=[BitConverter]::ToUInt32($pesSlot,64);generationAfter=[BitConverter]::ToUInt32($pesSlot,68);overlap=([BitConverter]::ToUInt32($pesSlot,88) -ne 0)}
  }
 }
 [PSCustomObject]@{pid=$pesProcess.Id;base=$pesBase;address=$pesFull;legacyAddress=$pesLegacy;head=$pesHead;enabled=($pesHeader[24] -eq 1);
  codeHex=[Convert]::ToHexString($pesCode);
  legacyCodeHex=[Convert]::ToHexString([PesEventReadOnly]::Read($pesReadHandle,$pesLegacy,679));
  contextCodeHex=[Convert]::ToHexString([PesEventReadOnly]::Read($pesReadHandle,$pesLegacy+0xa00,700));
  slots=$pesSlots;readOnly=$true} | ConvertTo-Json -Depth 4 -Compress
} finally { [void][PesEventReadOnly]::CloseHandle($pesReadHandle) }