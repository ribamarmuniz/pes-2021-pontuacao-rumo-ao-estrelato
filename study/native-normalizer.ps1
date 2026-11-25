param([Parameter(Mandatory)][string]$InputFile,[Parameter(Mandatory)][string]$OutputFile,[switch]$Raw)
$ErrorActionPreference='Stop'
Add-Type -Path (Join-Path $PSScriptRoot 'NativeNormalizer.cs')
[NativeNormalizer]::Run('C:\Games\PES2021\PES2021.exe',$InputFile,$OutputFile,$Raw.IsPresent)
