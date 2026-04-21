<#
.SYNOPSIS
    Создает пользователей Active Directory из CSV-файла
.DESCRIPTION
    Читает CSV с полями: FirstName, LastName, OU, Title, Department
    Автоматически генерирует логин (first.last) и временный пароль
#>

param(
    [Parameter(Mandatory)]
    [ValidateScript({Test-Path $_})]
    [string]$CSVPath,
    
    [Parameter()]
    [string]$DefaultOU = "OU=Users,DC=company,DC=com"
)

Import-Module ActiveDirectory -ErrorAction Stop

$users = Import-Csv $CSVPath
$results = @()
$logFile = "UserCreation_$(Get-Date -Format yyyyMMdd).log"

foreach ($user in $users) {
    $samAccountName = "$($user.FirstName).$($user.LastName)".ToLower()
    $userPrincipalName = "$samAccountName@company.com"
    $tempPassword = ConvertTo-SecureString "P@ssw0rd123!" -AsPlainText -Force
    
    try {
        New-ADUser -Name "$($user.FirstName) $($user.LastName)" `
                   -GivenName $user.FirstName `
                   -Surname $user.LastName `
                   -SamAccountName $samAccountName `
                   -UserPrincipalName $userPrincipalName `
                   -Title $user.Title `
                   -Department $user.Department `
                   -Path $user.OU `
                   -AccountPassword $tempPassword `
                   -Enabled $true `
                   -PassThru `
                   -ErrorAction Stop
        
        $results += [PSCustomObject]@{
            User = $samAccountName
            Status = "Created"
            OU = $user.OU
        }
        
        Add-Content $logFile -Value "[SUCCESS] $samAccountName created"
    } catch {
        $results += [PSCustomObject]@{
            User = $samAccountName
            Status = "Failed"
            Error = $_.Exception.Message
        }
        Add-Content $logFile -Value "[ERROR] $samAccountName : $_"
    }
}

$results | Export-Csv -Path "UserCreation_Results.csv" -NoTypeInformation
Write-Host "✅ Создано $($results.Where{$_.Status -eq 'Created'}.Count) пользователей" -ForegroundColor Green
