param([string]$CodeFile=(Join-Path $PSScriptRoot 'event-probe-test-code.bin'))
$ErrorActionPreference='Stop'
Add-Type -Path (Join-Path $PSScriptRoot 'EventProbeHarness.cs')
[EventProbeHarness]::Run($CodeFile)
