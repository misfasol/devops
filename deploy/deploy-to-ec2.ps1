<#
.SYNOPSIS
    Realiza o build e deploy da Loja Gamer diretamente do seu computador Windows para a EC2 na AWS.

.DESCRIPTION
    1. Cria a imagem Docker localmente.
    2. Exporta e compacta a imagem em image.tar.gz.
    3. Envia os arquivos para a EC2 (/opt/lojagamer/releases/<tag>) via SCP.
    4. Executa o deploy.sh via SSH na EC2.
    5. Valida o /healthz na porta 80.

.EXAMPLE
    .\deploy\deploy-to-ec2.ps1 -Ec2Host "34.201.50.12" -KeyPath "C:\Users\Striker\.ssh\minha-chave.pem"
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $true, HelpMessage = "IP Publico ou DNS da EC2")]
    [string]$Ec2Host,

    [Parameter(Mandatory = $true, HelpMessage = "Caminho do arquivo de chave SSH (.pem)")]
    [string]$KeyPath,

    [Parameter(Mandatory = $false)]
    [string]$User = "ec2-user",

    [Parameter(Mandatory = $false)]
    [string]$Tag = (Get-Date -Format "yyyyMMdd-HHmmss")
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $KeyPath)) {
    Write-Error "Arquivo de chave nao encontrado em: $KeyPath"
}

$RootDir = Resolve-Path "$PSScriptRoot\.."
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "  DEPLOIANDO LOJA GAMER NA AWS (EC2: $Ec2Host, Tag: $Tag)  " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Build da imagem Docker local
Write-Host "`n[1/5] Construindo imagem Docker (lojagamer:$Tag)..." -ForegroundColor Yellow
docker build -t "lojagamer:$Tag" -f "$RootDir\Dockerfile" "$RootDir"

# 2. Exportando e compactando imagem
$TempDir = "$RootDir\deploy\dist"
if (-not (Test-Path $TempDir)) {
    New-Item -ItemType Directory -Path $TempDir | Out-Null
}
$TarPath = "$TempDir\image.tar"
$GzPath = "$TempDir\image.tar.gz"

Write-Host "`n[2/5] Exportando imagem Docker..." -ForegroundColor Yellow
if (Test-Path $GzPath) { Remove-Item $GzPath -Force }
if (Test-Path $TarPath) { Remove-Item $TarPath -Force }

docker save "lojagamer:$Tag" -o $TarPath
Write-Host "Compactando com gzip..."
tar -czf $GzPath -C $TempDir image.tar
Remove-Item $TarPath -Force

# 3. Preparando pasta de release na EC2
Write-Host "`n[3/5] Criando diretorio de release na EC2..." -ForegroundColor Yellow
$RemoteReleaseDir = "/opt/lojagamer/releases/$Tag"
ssh -o StrictHostKeyChecking=no -i $KeyPath "$User@$Ec2Host" "mkdir -p $RemoteReleaseDir"

# 4. Enviando artefatos via SCP
Write-Host "`n[4/5] Enviando image.tar.gz e deploy.sh para a EC2..." -ForegroundColor Yellow
scp -o StrictHostKeyChecking=no -i $KeyPath $GzPath "$User@$Ec2Host`:$RemoteReleaseDir/image.tar.gz"
scp -o StrictHostKeyChecking=no -i $KeyPath "$RootDir\deploy\deploy.sh" "$User@$Ec2Host`:$RemoteReleaseDir/deploy.sh"

# 5. Executando o deploy na EC2
Write-Host "`n[5/5] Executando deploy.sh na EC2 via SSH..." -ForegroundColor Yellow
ssh -o StrictHostKeyChecking=no -i $KeyPath "$User@$Ec2Host" "bash $RemoteReleaseDir/deploy.sh $Tag"

Write-Host "`n==========================================================" -ForegroundColor Green
Write-Host "   DEPLOY FINALIZADO COM SUCESSO!                          " -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green
Write-Host "Acesse a aplicacao no navegador:" -ForegroundColor Cyan
Write-Host "  Loja Gamer:   http://$Ec2Host" -ForegroundColor White
Write-Host "  Health Check: http://$Ec2Host/healthz" -ForegroundColor White
Write-Host "  Metricas:     http://$Ec2Host/metrics" -ForegroundColor White
Write-Host "  Admin:        http://$Ec2Host/admin (Token: admin123)" -ForegroundColor White
