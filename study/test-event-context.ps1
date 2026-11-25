param([string]$CodeFile,[string]$PacketFile='')
$ErrorActionPreference='Stop'
Add-Type -Path (Join-Path $PSScriptRoot 'EventContextHarness.cs')
[EventContextHarness]::Run($CodeFile,$PacketFile)
