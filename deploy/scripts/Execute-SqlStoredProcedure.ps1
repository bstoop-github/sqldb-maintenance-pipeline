param(

    $sqlServerLogin = "xxx",
    $sqlServerPassword = "xxx",
    $ResourceGroupName = "xxx",
    $sqlServerName = "xxx",
    $createStoredProcedure = "D:\GIT\sqldb-maintenance-pipeline\deploy\scripts\createStoredProcedure.sql"

)

function Get-CurrentSqlCmdPath {
    <#
    .SYNOPSIS
    Returns sqlcmd.exe folder path

    .DESCRIPTION
    Search for sqlcmd bin path in system registry. First found version will be returned.

    .EXAMPLE
    Get-CurrentSqlCmdPath
    #> 

    [CmdletBinding()] 
    [OutputType([string])]
    param()

    $sqlServerVersions = @('170', '150', '140', '130', '120', '110', '100', '90')
    foreach ($version in $sqlServerVersions) {
        $regKey = "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\$version\Tools\ClientSetup"
        if (Test-Path -LiteralPath $regKey) {
            $regProperties = (Get-ItemProperty -Path $regKey)
            if ($regProperties.Path) {
                $path = Join-Path -Path $regProperties.Path -ChildPath 'sqlcmd.exe'
                if (Test-Path -LiteralPath $path) {
                    return $path
                }
            }
            if ($regProperties.ODBCToolsPath) {
                $path = Join-Path -Path $regProperties.ODBCToolsPath -ChildPath 'sqlcmd.exe'
                if (Test-Path -LiteralPath $path) {
                    return $path
                }
            }
        }
        # registry not found - try directory instead
        $path = "$($env:ProgramFiles)\Microsoft SQL Server\$version\Tools\Binn\sqlcmd.exe"
        if (Test-Path -LiteralPath $path) {
            return $path
        }
    }

    return $null
}

#Only use below while testing locally:

    #$subscriptionId = "xxx"
    #$tenantId = "xxx"
    #az login --tenant "$tenantId"
    #az account set --subscription "$subscriptionId"
    #az account list    
    
    #$sqlServerLogin = "xxx"
    #$sqlServerPassword = "xxx" 
    #$createStoredProcedure = "xxx\createStoredProcedure.sql"

#variables

    $qcd = "AzureSQLMaintenance 'all'"
    $SQLServer = "$($sqlServerName).database.windows.net"
    $GetAllDatabases = az sql db list --resource-group $ResourceGroupName --server $sqlServerName --query '[].name' -o tsv
    $localIp = (Invoke-RestMethod http://ipinfo.io/json | Select-Object -exp ip)

# Add IP address of build agent to whitelisting SQL server

    Write-Host "$ResourceGroupName"
    Write-Host "$SQLServer"
    Write-Host "$deploymentId"
    Write-Host "$localIp"

    try {
            az sql server firewall-rule create -g $ResourceGroupName -s $sqlServerName -n "buildagentIP" --start-ip-address $localIp --end-ip-address $localIp
        }
    catch {
            Write-Error $_.Exception.Message
            "Rule is already present." 
        }

    az sql server firewall-rule update -g $ResourceGroupName -s $sqlServerName -n "buildagentIP" --start-ip-address $localIp --end-ip-address $localIp


# Validating availability of sql cmd

    $installSqlcmd = Get-CurrentSqlCmdPath

    if($null -eq $installSqlcmd){
            Write-Host "Sqlcmd is not available, will install choco and sqlcmd utility.."
            $sqlcmd = $false
        }
    else{
            Write-Host "Sqlcmd is available and installed, skipping installation."
            $sqlcmd = $true
        }

    if($sqlcmd -eq $false){

#install choco

    # If a private build agent and you require admin right to install choco and/or sqlcmd, you might want to install sqlcmd manually without the use of choco using:
    # https://go.microsoft.com/fwlink/?linkid=2168524 (ODBC driver)
    # https://go.microsoft.com/fwlink/?linkid=2142258 (SQLCMD)

    try {
            $testchoco = choco -v    
        }
    catch {
            Write-Host "Chocolotay is not installed."
        }

    if(-not($testchoco)){
            Write-Output "Seems Chocolatey is not installed, installing now"
            Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'));
        }
    else{
            Write-Output "Chocolatey Version $testchoco is already installed"
        }

        refreshenv;

#install sqlcmd

    try {
            $installedModule = choco list sqlserver-cmdlineutils
        }
    catch {
            Write-Host "Sqlserver-cmdlineutils is not installed."
        }

    if(-not($installedModule)){
            choco install sqlserver-cmdlineutils -f -y
        }
    else{
            Write-Output "Sqlserver-cmdlineutils is already installed"
        }
}

#Create stored procedures on all databases

    foreach($db in $GetAllDatabases){
        if ($db -ne "master"){

            Sqlcmd -S $SQLServer -d $db -i $createStoredProcedure -U $sqlServerLogin -P $sqlServerPassword
            Write-Host "Stored procedure to setup periodic maintenance has been created in database $db"
        
        }
    }

#Execute stored procedures on all databases

    foreach($db in $GetAllDatabases){
        if ($db -ne "master"){

            Sqlcmd -S $SQLServer -d $db -q $qcd -U $sqlServerLogin -P $sqlServerPassword
            Write-Host "Stored procedure executed on database $db"

        }
    }