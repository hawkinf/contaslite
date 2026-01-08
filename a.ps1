function Show-Menu {
    Clear-Host
    Write-Host "==============================================" -ForegroundColor Cyan
    Write-Host "      GIT HELPER - FLUTTER TOOL               " -ForegroundColor Cyan
    Write-Host "==============================================" -ForegroundColor Cyan
    Write-Host "1. [SAVE] Apenas Commit Local"
    Write-Host "2. [SYNC] Commit + Push (Salva e envia tudo)"
    Write-Host "3. [PUSH] Enviar commits pendentes (Push)"
    Write-Host "4. [BRANCH] Criar nova Branch de teste"
    Write-Host "5. [LIST] Ver Branches"
    Write-Host "6. [UNDO] VOLTAR ATRÁS (Apagar mudanças atuais)"
    Write-Host "7. [FIX] Flutter Clean & Pub Get"
    Write-Host "8. [STATUS] Ver arquivos alterados"
    Write-Host "Q. Sair"
    Write-Host "==============================================" -ForegroundColor Cyan
}

do {
    Show-Menu
    $input = Read-Host "Escolha uma opção"
    $currentBranch = git branch --show-current

    switch ($input) {
        '1' {
            $msg = Read-Host "Mensagem do commit"
            git add .
            git commit -m "$msg"
            Write-Host "Salvo localmente!" -ForegroundColor Green
            Pause
        }
        '2' {
            $msg = Read-Host "Mensagem do commit"
            git add .
            git commit -m "$msg"
            Write-Host "Enviando para $currentBranch..." -ForegroundColor Magenta
            git push origin $currentBranch
            Pause
        }
        '3' {
            Write-Host "Enviando alterações pendentes..." -ForegroundColor Magenta
            git push origin $currentBranch
            Pause
        }
        '4' {
            $nome = Read-Host "Nome da branch"
            git checkout -b $nome
            Pause
        }
        '5' {
            git branch
            Pause
        }
        '6' {
            $confirm = Read-Host "CUIDADO: Descartar todas as mudanças atuais? (S/N)"
            if ($confirm -eq 'S' -or $confirm -eq 's') {
                git reset --hard HEAD
                Write-Host "Reset efetuado!" -ForegroundColor Red
            }
            Pause
        }
        '7' {
            Write-Host "Limpando e atualizando Flutter..." -ForegroundColor Cyan
            flutter clean; flutter pub get
            Pause
        }
        '8' {
            git status
            Pause
        }
    }
} while ($input -ne 'q')