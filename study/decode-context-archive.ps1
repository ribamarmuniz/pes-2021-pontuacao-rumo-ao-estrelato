param([Parameter(Mandatory)][string]$InputFile,[string]$RawFixture='')
$ErrorActionPreference='Stop'
Add-Type -Path @((Join-Path $PSScriptRoot 'ContextCompression.cs'),(Join-Path $PSScriptRoot 'ContextArchive.cs'))
if ($RawFixture) { [ContextArchive]::WriteFixture($RawFixture,$InputFile) }
[ContextArchive]::TranscodeToStdout($InputFile)
