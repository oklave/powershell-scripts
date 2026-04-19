<#
.SYNOPSIS
    Находит пользователей, не входивших в систему более N дней
.DESCRIPTION
    Анализирует атрибут LastLogonDate и экспортирует отчет в CSV
#>

param(
    [Parameter()]
    [int]$DaysInactive = 90,
    
    [Parameter()]
    [string]$SearchBase = "OU=Users,DC=company,DC=com",
    
    [Parameter()]
    [switch]$DisableAccounts
)

Import-Module ActiveDirectory

$inactiveDate = (Get-Date).AddDays(-$DaysInactive)

$inactiveUsers = Get-ADUser -Filter {Enabled -eq $true -and LastLogonDate -lt $inactiveDate} `
                            -SearchBase $SearchBase `
                            -Properties LastLogonDate, Department, Manager

$report = foreach ($user in $inactiveUsers) {
    [PSCustomObject]@{
        Name = $user.Name
        SamAccountName = $user.SamAccountName
        LastLogon = $user.LastLogonDate
        Department = $user.Department
        Manager = $user.Manager
        DaysInactive = [math]::Round((Get-Date - $user.LastLogonDate).TotalDays)
    }
}

$report | Export-Csv -Path "InactiveUsers_$DaysInactive days.csv" -NoTypeInformation

Write-Host "📊 Найдено $($report.Count) неактивных пользователей" -ForegroundColor Yellow

if ($DisableAccounts -and $report.Count -gt 0) {
    Write-Host "⚠️ Будет выполнено отключение учетных записей..." -ForegroundColor Red
    $confirm = Read-Host "Отключить найденные аккаунты? (Y/N)"
    
    if ($confirm -eq 'Y') {
        foreach ($user in $inactiveUsers) {
            Disable-ADAccount -Identity $user.SamAccountName
            Write-Host "  Отключен: $($user.SamAccountName)" -ForegroundColor Gray
        }
    }
}
