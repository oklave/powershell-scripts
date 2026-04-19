<#
.SYNOPSIS
    Проверяет AD на соответствие базовым security best practices
.DESCRIPTION
    Проверяет: пустые пароли, аккаунты без смены пароля, администраторов с правами
#>

Import-Module ActiveDirectory

Write-Host "🔐 Security Baseline Check for Active Directory" -ForegroundColor Cyan

# 1. Пользователи с пустым паролем
$blankPasswords = Get-ADUser -Filter "UserPrincipalName -ne '$null'" `
                              -Properties PasswordLastSet |
    Where-Object { $_.PasswordLastSet -eq $null -or $_.PasswordLastSet -eq 0 }

# 2. Пользователи с паролем, не менявшимся > 365 дней
$expiredPasswords = Get-ADUser -Filter {Enabled -eq $true} `
                                -Properties PasswordLastSet |
    Where-Object { (Get-Date) - $_.PasswordLastSet -gt (New-TimeSpan -Days 365) }

# 3. Domain Admins (критическая проверка)
$domainAdmins = Get-ADGroupMember -Identity "Domain Admins" | 
    Where-Object { $_.objectClass -eq 'user' }

$report = @{
    "BlankPasswords" = $blankPasswords.Count
    "ExpiredPasswords" = $expiredPasswords.Count
    "DomainAdminsCount" = $domainAdmins.Count
    "DomainAdmins" = $domainAdmins.SamAccountName -join ", "
}

Write-Host "`n📋 Результаты проверки:" -ForegroundColor Yellow
Write-Host "  • Пользователей с пустым паролем: $($report.BlankPasswords)" -ForegroundColor $(if($report.BlankPasswords -gt 0){'Red'}else{'Green'})
Write-Host "  • Пароль старше 365 дней: $($report.ExpiredPasswords)" -ForegroundColor $(if($report.ExpiredPasswords -gt 10){'Yellow'}else{'Green'})
Write-Host "  • Членов Domain Admins: $($report.DomainAdminsCount)" -ForegroundColor $(if($report.DomainAdminsCount -gt 5){'Yellow'}else{'Green'})
Write-Host "  • Администраторы: $($report.DomainAdmins)" -ForegroundColor Gray
