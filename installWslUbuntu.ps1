<#
.SYNOPSIS
    Автоматическая установка WSL с Ubuntu на Windows 10/11
.DESCRIPTION
    Скрипт проверяет наличие WSL, устанавливает его при отсутствии,
    настраивает WSL 2 и устанавливает Ubuntu.
.NOTES
    Требуются права администратора
#>

#Requires -RunAsAdministrator

# Настройки
$WSL_DISTRO = "Ubuntu-24.04"  # Можно изменить на: Ubuntu-22.04, Ubuntu-20.04
$REBOOT_REQUIRED = $false

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "   WSL + Ubuntu Installer for Windows   " -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Функция для проверки и включения компонентов Windows
function Enable-WindowsFeatures {
    Write-Host "[1/5] Проверка компонентов Windows..." -ForegroundColor Yellow
    
    $features = @(
        "Microsoft-Windows-Subsystem-Linux",
        "VirtualMachinePlatform"
    )
    
    foreach ($feature in $features) {
        $check = Get-WindowsOptionalFeature -Online -FeatureName $feature
        if ($check.State -eq "Disabled") {
            Write-Host "  Включение: $feature" -ForegroundColor Yellow
            Enable-WindowsOptionalFeature -Online -FeatureName $feature -All -NoRestart
            $script:REBOOT_REQUIRED = $true
        } else {
            Write-Host "  Уже включен: $feature" -ForegroundColor Green
        }
    }
}

# Функция проверки наличия WSL
function Test-WSLInstalled {
    try {
        $result = wsl --status 2>&1
        return $true
    } catch {
        return $false
    }
}

# Функция установки WSL
function Install-WSL {
    Write-Host "[2/5] Установка WSL..." -ForegroundColor Yellow
    
    if (Test-WSLInstalled) {
        Write-Host "  WSL уже установлен" -ForegroundColor Green
        return
    }
    
    try {
        # Установка WSL через официальную команду [citation:3][citation:5]
        wsl --install --no-distribution
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  WSL успешно установлен" -ForegroundColor Green
            $script:REBOOT_REQUIRED = $true
        } else {
            # Альтернативный метод для старых версий Windows [citation:9]
            Write-Host "  Альтернативный метод установки..." -ForegroundColor Yellow
            dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
            dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart
            $script:REBOOT_REQUIRED = $true
        }
    } catch {
        Write-Host "  Ошибка установки WSL: $_" -ForegroundColor Red
        exit 1
    }
}

# Функция настройки WSL 2
function Set-WSL2Default {
    Write-Host "[3/5] Настройка WSL 2 как версии по умолчанию..." -ForegroundColor Yellow
    
    try {
        # Установка WSL 2 по умолчанию [citation:8]
        wsl --set-default-version 2
        
        if ($LASTEXITCODE -ne 0) {
            Write-Host "  Обновление ядра WSL..." -ForegroundColor Yellow
            Write-Host "  Скачайте и установите пакет обновления ядра Linux:"
            Write-Host "  https://learn.microsoft.com/ru-ru/windows/wsl/install-manual#step-4---download-the-linux-kernel-update-package" -ForegroundColor Cyan
        }
    } catch {
        Write-Host "  Предупреждение: $_" -ForegroundColor Yellow
    }
}

# Функция установки Ubuntu
function Install-Ubuntu {
    Write-Host "[4/5] Установка $WSL_DISTRO..." -ForegroundColor Yellow
    
    # Проверка, не установлена ли уже Ubuntu
    $installed = wsl --list --quiet 2>$null
    if ($installed -match $WSL_DISTRO) {
        Write-Host "  $WSL_DISTRO уже установлена" -ForegroundColor Green
        return
    }
    
    try {
        # Установка Ubuntu через WSL [citation:2][citation:10]
        wsl --install -d $WSL_DISTRO
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  $WSL_DISTRO успешно установлена" -ForegroundColor Green
        } else {
            # Альтернативный метод с веб-загрузкой [citation:5]
            Write-Host "  Повторная попытка с веб-загрузкой..." -ForegroundColor Yellow
            wsl --install --web-download -d $WSL_DISTRO
        }
    } catch {
        Write-Host "  Ошибка установки Ubuntu: $_" -ForegroundColor Red
        exit 1
    }
}

# Функция финальной проверки
function Show-WSLStatus {
    Write-Host "[5/5] Проверка статуса..." -ForegroundColor Yellow
    
    Write-Host "`n--- Статус WSL ---" -ForegroundColor Cyan
    wsl --status
    
    Write-Host "`n--- Установленные дистрибутивы ---" -ForegroundColor Cyan
    wsl --list --verbose
    
    Write-Host "`n--- Запуск Ubuntu ---" -ForegroundColor Cyan
    Write-Host "Для первого запуска выполните в терминале: wsl -d $WSL_DISTRO" -ForegroundColor White
    Write-Host "При первом запуске будет предложено создать пользователя и пароль." -ForegroundColor Yellow
}

# Основная логика
function Main {
    # Проверка версии Windows
    $osInfo = Get-ComputerInfo | Select-Object WindowsVersion, WindowsBuildLabEx
    Write-Host "Система: Windows $($osInfo.WindowsVersion)" -ForegroundColor Gray
    
    # Минимальные требования: Windows 10 версии 2004+ [citation:3][citation:5]
    $buildNumber = [Environment]::OSVersion.Version.Build
    if ($buildNumber -lt 19041) {
        Write-Host "ОШИБКА: Требуется Windows 10 версии 2004 (сборка 19041) или новее" -ForegroundColor Red
        Write-Host "Текущая сборка: $buildNumber" -ForegroundColor Red
        exit 1
    }
    
    # Включение компонентов
    Enable-WindowsFeatures
    
    # Установка WSL
    Install-WSL
    
    # Настройка WSL 2
    Set-WSL2Default
    
    # Если требуется перезагрузка
    if ($REBOOT_REQUIRED) {
        Write-Host "`n========================================" -ForegroundColor Cyan
        Write-Host "   Требуется перезагрузка компьютера   " -ForegroundColor Yellow
        Write-Host "========================================" -ForegroundColor Cyan
        $response = Read-Host "Перезагрузить сейчас? (Y/N)"
        if ($response -eq 'Y') {
            Restart-Computer -Force
        } else {
            Write-Host "После перезагрузки запустите скрипт снова для завершения установки." -ForegroundColor Yellow
            exit 0
        }
    }
    
    # Установка Ubuntu
    Install-Ubuntu
    
    # Финальная проверка
    Show-WSLStatus
    
    Write-Host "`n========================================" -ForegroundColor Green
    Write-Host "   Установка завершена успешно!   " -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
}

# Запуск скрипта
Main
