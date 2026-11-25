$ErrorActionPreference='Stop'
Add-Type -Path (Join-Path $PSScriptRoot 'ContextCompression.cs')
$pesCompressionResult=[ContextCompression]::Selftest()
$pesCompressionResult | Set-Content -LiteralPath (Join-Path $PSScriptRoot 'context-compression-selftest.json') -Encoding utf8
$pesCompressionResult
