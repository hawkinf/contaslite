# Verifica se é um repositório git
if (!(Test-Path .git)) {
    Write-Host "Erro: Este diretório não é um repositório Git." -ForegroundColor Red
    exit
}

# Obtém a data e hora atual para a mensagem
$data = Get-Date -Format "dd/MM/yyyy HH:mm"
$mensagem = "Backup pré-alteração: $data"

Write-Host "Salvando estado atual do projeto Flutter..." -ForegroundColor Cyan

# Comandos Git
git add .
git commit -m "$mensagem"

Write-Host "Sucesso! Se precisar voltar, use: git reset --hard HEAD" -ForegroundColor Green