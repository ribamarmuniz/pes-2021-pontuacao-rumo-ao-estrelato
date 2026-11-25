param([string]$Version='0.10')
$ErrorActionPreference='Stop'
if ($Version -notmatch '^0\.\d+$') { throw 'Versao invalida' }
Add-Type -AssemblyName System.IO.Compression
$pesApp=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$pesOutput=[IO.Directory]::GetParent($pesApp).FullName
$pesManifestPath=Join-Path $PSScriptRoot 'release-manifest.json'
if (Test-Path -LiteralPath $pesManifestPath) {
 $pesManifest=@(Get-Content -LiteralPath $pesManifestPath -Raw | ConvertFrom-Json)
} else {
 $pesOld=[IO.Compression.ZipFile]::OpenRead((Join-Path $pesOutput 'PES2021-Sider-HUD-0.9.zip'))
 try { $pesManifest=@($pesOld.Entries | Where-Object { $_.Name -ne '' } | ForEach-Object { $_.FullName }) }
 finally { $pesOld.Dispose() }
 $pesManifest | ConvertTo-Json | Set-Content -LiteralPath $pesManifestPath -Encoding utf8
}
if ($pesManifest.Count -ne 26) { throw 'Manifesto de distribuicao inesperado' }
$pesZipPath=Join-Path $pesOutput ('PES2021-Sider-HUD-'+$Version+'.zip')
if (Test-Path -LiteralPath $pesZipPath) { throw 'Pacote ja existe, confira antes de substituir' }
$pesSources=@{}
foreach ($pesEntry in $pesManifest) {
 if (-not $pesEntry.StartsWith('PES2021-Sider-HUD/') -or $pesEntry.Contains('..') -or $pesEntry -match '(^|/)(study|startup.cache)(/|$)|\.log$|(^|/)PES2021.exe$') { throw 'Entrada fora da distribuicao' }
 $pesFile=[IO.Path]::GetFullPath((Join-Path $pesOutput $pesEntry))
 if (-not $pesFile.StartsWith($pesApp+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)) { throw 'Caminho fora da aplicacao' }
 $pesItem=Get-Item -LiteralPath $pesFile
 if ($pesItem.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Fonte redirecionada' }
 $pesSources[$pesEntry]=$pesFile
}
$pesZip=[IO.Compression.ZipFile]::Open($pesZipPath,[IO.Compression.ZipArchiveMode]::Create)
try { foreach ($pesEntry in $pesManifest) { [void][IO.Compression.ZipFileExtensions]::CreateEntryFromFile($pesZip,$pesSources[$pesEntry],$pesEntry,[IO.Compression.CompressionLevel]::Optimal) } }
finally { $pesZip.Dispose() }
$pesZip=[IO.Compression.ZipFile]::OpenRead($pesZipPath)
try {
 foreach ($pesEntry in $pesZip.Entries) {
  $pesHash=[Security.Cryptography.SHA256]::Create()
  $pesStream=$pesEntry.Open()
  try { $pesArchived=[Convert]::ToHexString($pesHash.ComputeHash($pesStream)) }
  finally { $pesStream.Dispose();$pesHash.Dispose() }
  if ($pesArchived -ne (Get-FileHash -LiteralPath $pesSources[$pesEntry.FullName] -Algorithm SHA256).Hash) { throw 'Arquivo compactado diferente da fonte' }
 }
 if ($pesZip.Entries.Count -ne 26) { throw 'Contagem de entradas divergente' }
} finally { $pesZip.Dispose() }
$pesReport=[PSCustomObject]@{version=$Version;package=$pesZipPath;files=26;filesMatch=$true;
 sha256=(Get-FileHash -LiteralPath $pesZipPath -Algorithm SHA256).Hash;
 moduleSha256=(Get-FileHash -LiteralPath (Join-Path $pesApp 'modules\bal_painel.lua') -Algorithm SHA256).Hash;
 excludedLogs=$true;excludedStudy=$true;excludedOriginalGameExe=$true}
$pesReport | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $PSScriptRoot 'package-validation.json') -Encoding utf8
$pesReport | ConvertTo-Json
