# ============================================================
# DEPLOY CIS - Flutter Web
# ============================================================

$ErrorActionPreference = "Stop"

# ============================================================
# CONFIG
# ============================================================

$projectPath = "D:\project kerja\flutter\CIS"

$sshKey = "C:\Users\USER\.ssh\productionkey.pem"

$serverUser = "ecustomer"
$serverHost = "103.129.149.131"

$zipName = "3200pm.zip"
$zipPath = Join-Path $projectPath $zipName

$remoteUploadPath = "/home/ecustomer/$zipName"
$remoteWebPath = "/var/www/cis"

$containerName = "cis"

# ============================================================
# FUNCTION
# ============================================================

function Run-SSH {
    param (
        [string]$Command
    )

    Write-Host ""
    Write-Host "SERVER > $Command" -ForegroundColor DarkGray

    ssh -i $sshKey "${serverUser}@${serverHost}" $Command

    if ($LASTEXITCODE -ne 0) {
        throw "Command server gagal: $Command"
    }
}

# ============================================================
# START
# ============================================================

Write-Host ""
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "             DEPLOY CIS FLUTTER WEB" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan

# ============================================================
# 1. MASUK PROJECT
# ============================================================

Write-Host ""
Write-Host "=== PROJECT ===" -ForegroundColor Cyan

Set-Location $projectPath

Write-Host "Project: $projectPath"

# ============================================================
# 2. BUILD
# ============================================================

Write-Host ""
Write-Host "=== FLUTTER CLEAN ===" -ForegroundColor Cyan

flutter clean

if ($LASTEXITCODE -ne 0) {
    throw "flutter clean gagal."
}

Write-Host ""
Write-Host "=== FLUTTER PUB GET ===" -ForegroundColor Cyan

flutter pub get

if ($LASTEXITCODE -ne 0) {
    throw "flutter pub get gagal."
}

Write-Host ""
Write-Host "=== FLUTTER BUILD WEB ===" -ForegroundColor Cyan

flutter build web

if ($LASTEXITCODE -ne 0) {
    throw "flutter build web gagal."
}

# ============================================================
# 3. CEK BUILD
# ============================================================

Write-Host ""
Write-Host "=== CEK HASIL BUILD ===" -ForegroundColor Cyan

$indexFile = Join-Path $projectPath "build\web\index.html"

if (-not (Test-Path $indexFile)) {
    throw "build\web\index.html tidak ditemukan."
}

$title = Select-String `
    -Path $indexFile `
    -Pattern "<title>" |
    Select-Object -First 1

Write-Host "Title:"
Write-Host $title.Line

# ============================================================
# 4. HAPUS ZIP LAMA
# ============================================================

Write-Host ""
Write-Host "=== HAPUS ZIP LAMA ===" -ForegroundColor Cyan

if (Test-Path $zipPath) {
    Remove-Item $zipPath -Force
}

# ============================================================
# 5. BUAT ZIP
# ============================================================

Write-Host ""
Write-Host "=== MEMBUAT ZIP ===" -ForegroundColor Cyan

Compress-Archive `
    -Path "$projectPath\build\web\*" `
    -DestinationPath $zipPath `
    -Force

if (-not (Test-Path $zipPath)) {
    throw "ZIP gagal dibuat."
}

$zipSize = (Get-Item $zipPath).Length / 1MB

Write-Host ("ZIP berhasil dibuat: {0:N2} MB" -f $zipSize) -ForegroundColor Green

# ============================================================
# 6. UPLOAD
# ============================================================

Write-Host ""
Write-Host "=== UPLOAD KE SERVER ===" -ForegroundColor Cyan

scp `
    -i $sshKey `
    $zipPath `
    "${serverUser}@${serverHost}:${remoteUploadPath}"

if ($LASTEXITCODE -ne 0) {
    throw "Upload ZIP gagal."
}

Write-Host "Upload berhasil." -ForegroundColor Green

# ============================================================
# 7. CEK ZIP DI SERVER
# ============================================================

Write-Host ""
Write-Host "=== CEK ZIP DI SERVER ===" -ForegroundColor Cyan

Run-SSH "ls -lh $remoteUploadPath"

# ============================================================
# 8. PINDAHKAN ZIP
# ============================================================

Write-Host ""
Write-Host "=== PINDAHKAN ZIP ===" -ForegroundColor Cyan

Run-SSH "sudo mv $remoteUploadPath $remoteWebPath/$zipName"

# ============================================================
# 9. EXTRACT
# ============================================================

Write-Host ""
Write-Host "=== EXTRACT ZIP ===" -ForegroundColor Cyan

Write-Host ""
Write-Host "SERVER > cd $remoteWebPath && sudo unzip -o $zipName" -ForegroundColor DarkGray

ssh -i $sshKey "${serverUser}@${serverHost}" "cd $remoteWebPath && sudo unzip -o $zipName"

# unzip bisa mengembalikan exit code non-zero karena warning
# meskipun file tetap berhasil diekstrak.
if ($LASTEXITCODE -gt 1) {
    throw "Extract ZIP gagal."
}

Write-Host "Extract selesai." -ForegroundColor Green

# ============================================================
# 10. CEK INDEX.HTML
# ============================================================

Write-Host ""
Write-Host "=== CEK FILE INDEX ===" -ForegroundColor Cyan

Run-SSH "grep -i '<title>' $remoteWebPath/index.html"

# ============================================================
# 11. CEK CONTAINER
# ============================================================

Write-Host ""
Write-Host "=== CEK CONTAINER CIS ===" -ForegroundColor Cyan

Run-SSH "sudo docker ps --filter name=$containerName --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'"

# ============================================================
# 12. RESTART CONTAINER
# ============================================================

Write-Host ""
Write-Host "=== RESTART CONTAINER CIS ===" -ForegroundColor Cyan

Run-SSH "sudo docker restart $containerName"

# ============================================================
# 13. CEK CONTAINER SETELAH RESTART
# ============================================================

Write-Host ""
Write-Host "=== CEK STATUS CIS ===" -ForegroundColor Cyan

Run-SSH "sudo docker ps --filter name=$containerName --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'"

# ============================================================
# 14. CEK FILE DI DALAM CONTAINER
# ============================================================

Write-Host ""
Write-Host "=== CEK INDEX DI CONTAINER ===" -ForegroundColor Cyan

Run-SSH "sudo docker exec $containerName grep -i '<title>' /usr/share/nginx/html/index.html"

# ============================================================
# SELESAI
# ============================================================

Write-Host ""
Write-Host "==================================================" -ForegroundColor Green
Write-Host "             DEPLOY CIS BERHASIL" -ForegroundColor Green
Write-Host "==================================================" -ForegroundColor Green
Write-Host ""
Write-Host "URL:"
Write-Host "http://103.129.149.131:3200" -ForegroundColor Cyan
Write-Host ""