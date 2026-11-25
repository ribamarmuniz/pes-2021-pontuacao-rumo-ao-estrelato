param([string]$Address='140a20020',[int]$Count=180)
$source=@'
using System;
using System.Text;
using System.Runtime.InteropServices;
public static class PesStaticCode {
 [DllImport("dbgeng.dll",PreserveSig=true)] static extern int DebugCreate(in Guid iid,out IntPtr obj);
 [UnmanagedFunctionPointer(CallingConvention.StdCall)] delegate int OpenDump(IntPtr self,[MarshalAs(UnmanagedType.LPStr)]string path);
 [UnmanagedFunctionPointer(CallingConvention.StdCall)] delegate int Wait(IntPtr self,uint flags,uint timeout);
 [UnmanagedFunctionPointer(CallingConvention.StdCall)] delegate int Dis(IntPtr self,ulong addr,uint flags,StringBuilder b,uint length,out uint used,out ulong next);
 static T Slot<T>(IntPtr obj,int n) where T:Delegate => Marshal.GetDelegateForFunctionPointer<T>(Marshal.ReadIntPtr(Marshal.ReadIntPtr(obj),n*IntPtr.Size));
 public static string Read(string file,ulong addr,int count) {
  Guid cid=new Guid("27fe5639-8407-4f47-8364-ee118fb08ac8"),ctl=new Guid("5182e668-105e-416e-ad92-24ef800424ba");
  IntPtr client,control;int hr=DebugCreate(in cid,out client);if(hr<0)Marshal.ThrowExceptionForHR(hr);
  try { hr=Marshal.QueryInterface(client,in ctl,out control);if(hr<0)Marshal.ThrowExceptionForHR(hr);
   try {hr=Slot<OpenDump>(client,19)(client,file);if(hr<0)Marshal.ThrowExceptionForHR(hr);hr=Slot<Wait>(control,93)(control,0,5000);if(hr<0)Marshal.ThrowExceptionForHR(hr);
    var output=new StringBuilder();var decoder=Slot<Dis>(control,26);for(int i=0;i<count;i++){var line=new StringBuilder(1024);uint used;ulong next;hr=decoder(control,addr,0,line,1024,out used,out next);if(hr<0||next<=addr)break;output.Append(line);addr=next;}return output.ToString();
   }finally{Marshal.Release(control);}
  }finally{Marshal.Release(client);}
 }
}
'@
Add-Type -TypeDefinition $source
[PesStaticCode]::Read((Join-Path $PSScriptRoot 'static.dmp'),[Convert]::ToUInt64($Address,16),$Count)
