# Script para tirar snapshot automático do projeto
# Uso: .\snapshot.ps1

$projectPath = "c:\flutter\Contaslite"
$snapshotDir = "$projectPath\.snapshots"

# Criar diretório de snapshots se não existir
if (!(Test-Path $snapshotDir)) {
    New-Item -ItemType Directory -Force -Path $snapshotDir | Out-Null
}

# Gerar timestamp no formato YYYY-MM-DDTHH-MM-SS
$timestamp = Get-Date -Format "yyyy-MM-ddTHH-mm-ss"
$snapshotFolder = "$snapshotDir\snapshot-$timestamp"

# Criar pasta do snapshot
New-Item -ItemType Directory -Force -Path $snapshotFolder | Out-Null

Write-Host "📸 Tirando snapshot do projeto..." -ForegroundColor Cyan
Write-Host "📁 Destino: $snapshotFolder" -ForegroundColor Cyan

# Copiar arquivos importantes (excluindo build, .git, etc)
$excludePatterns = @(
    ".git",
    "build",
    ".dart_tool",
    ".idea",
    "ios/Pods",
    "ios/Podfile.lock",
    ".flutter-plugins",
    ".flutter-plugins-dependencies",
    ".packages",
    "pubspec.lock",
    ".vscode",
    ".snapshots"
)

# Copiar projeto
Copy-Item -Path "$projectPath\*" -Destination $snapshotFolder -Recurse -Force -Exclude $excludePatterns

Write-Host "✅ Snapshot criado com sucesso!" -ForegroundColor Green
Write-Host "📂 Local: $snapshotFolder" -ForegroundColor Green

# Mostrar tamanho do snapshot
$size = (Get-ChildItem -Path $snapshotFolder -Recurse | Measure-Object -Property Length -Sum).Sum / 1MB
Write-Host "💾 Tamanho: $([Math]::Round($size, 2)) MB" -ForegroundColor Green

# Listar últimos 5 snapshots
Write-Host "" -ForegroundColor Green
Write-Host "📋 Últimos snapshots:" -ForegroundColor Cyan
Get-ChildItem -Path $snapshotDir -Directory | Sort-Object CreationTime -Descending | Select-Object -First 5 | ForEach-Object {
    $itemSize = (Get-ChildItem -Path $_.FullName -Recurse | Measure-Object -Property Length -Sum).Sum / 1MB
    Write-Host "  - $($_.Name) ($([Math]::Round($itemSize, 2)) MB)" -ForegroundColor Gray
}
