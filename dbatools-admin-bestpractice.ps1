# IF THIS SCRIPT IS RUN ON LOCAL SQL INSTANCES, YOU MUST RUN ISE OR POWERSHELL AS ADMIN
# Otherwise, a bunch of commands won't work.

# Paths that auto-load modules
$env:PSModulePath -Split ";"

# This is the [development] aka beta branch
Import-Module C:\github\dbatools -Force

# Set some vars
$new = "sql2016\vnext"
$old = $instance = "sql2014"
$coupleservers = "sql2012","sql2016"
$allservers = "sql2008","sql2012","sql2014","sql2016", "sql2016a","sql2016b","sql2016c","sqlcluster","sql2005"

# MY NEW TRIck (thanks @alexandair, et al)
break

#region configs

# Get-DbaSpConfigure - @sirsql
$oldprops = Get-DbaSpConfigure -SqlServer $old
$newprops = Get-DbaSpConfigure -SqlServer $new

$propcompare = foreach ($prop in $oldprops) {
    [pscustomobject]@{
    Config = $prop.DisplayName
    'SQL Server 2014' = $prop.RunningValue
    'SQL Server 2016' = $newprops | Where ConfigName -eq $prop.ConfigName | Select -ExpandProperty RunningValue
    }
} 

$propcompare | Out-GridView

# Copy-SqlSpConfigure
Copy-SqlSpConfigure -Source $old -Destination $new -Configs DefaultBackupCompression, IsSqlClrEnabled

# Get-DbaSpConfigure - @sirsql
Get-DbaSpConfigure -SqlServer $new | Where-Object { $_.ConfigName -in 'DefaultBackupCompression', 'IsSqlClrEnabled' } | 
Select-Object ConfigName, RunningValue, IsRunningDefaultValue | Format-Table -AutoSize

#endregion

#region backuprestore

Start-Process https://dbatools.io/snowball

# standard
Restore-DbaDatabase -SqlServer localhost -Path C:\temp\SQL2016_Cube_Query_History_FULL_20170206_115448.bak
Restore-DbaDatabase -SqlServer localhost -Path C:\temp\SQL2016_Cube_Query_History_FULL_20170206_115448.bak -WithReplace

# ola!
Invoke-Item \\nas\sql\SQL2016\db1
Restore-DbaDatabase -SqlServer sql2016 -Path \\nas\sql\SQL2016\db1 -WithReplace -DestinationDataDirectory C:\temp

foreach ($database in (Get-ChildItem -Directory \\nas\sql\SQL2016).FullName)
{
    Write-Output "Processing $database"
    Restore-DbaDatabase -SqlServer sql2016\vnext -Path $database -NoRecovery # -RestoreTime (Get-date).AddHours(-3)
}

# What about backups?
Get-DbaDatabase -SqlInstance sql2005 -Databases db_2005_CL80 | Backup-DbaDatabase -BackupDirectory C:\temp -NoCopyOnly

# history
Get-DbaBackupHistory -SqlServer sql2005 -Databases dumpsterfire4, db_2005_CL80 | Out-GridView

# backup header
Read-DbaBackupHeader -SqlServer $instance -Path "\\nas\sql\SQL2016\db1\FULL\SQL2016_db1_FULL_20170206_115448.bak"
Read-DbaBackupHeader -SqlServer $instance -Path "\\nas\sql\SQL2016\db1\FULL\SQL2016_db1_FULL_20170206_115448.bak" | SELECT ServerName, DatabaseName, UserName, BackupFinishDate, SqlVersion, BackupSizeMB
Read-DbaBackupHeader -SqlServer $instance -Path "\\nas\sql\SQL2016\db1\FULL\SQL2016_db1_FULL_20170206_115448.bak" -FileList  | Out-GridView

# Find it!
Find-DbaCommand -Tag Backup

#endregion

#region SPN
Start-Process https://dbatools.io/schwifty
Start-Process "C:\Program Files\Microsoft\Kerberos Configuration Manager for SQL Server\KerberosConfigMgr.exe"

Get-DbaSpn | Format-Table
$allservers | Test-DbaSpn | Out-GridView -PassThru | Set-DbaSpn -Whatif
Get-DbaSpn | Remove-DbaSpn -Whatif

#endregion

#region holiday
# Get-DbaLastBackup - by @powerdbaklaas
$allservers | Get-DbaLastBackup | Out-GridView
$allservers | Get-DbaLastBackup | Where-Object LastFullBackup -eq $null | Format-Table -AutoSize
$allservers | Get-DbaLastBackup | Where-Object { $_.SinceLog -gt '00:15:00' -and $_.RecoveryModel -ne 'Simple' -and $_.Database -ne 'model' } | Select Server, Database, SinceFull, DatabaseCreated | Out-GridView

# LastGoodCheckDb - by @jagoop
$checkdbs = Get-DbaLastGoodCheckDb -SqlServer $instance
$checkdbs
$checkdbs | Where LastGoodCheckDb -eq $null
$checkdbs | Where LastGoodCheckDb -lt (Get-Date).AddDays(-1)

# Disk Space - by a bunch of us
Get-DbaDiskSpace -SqlInstance $allservers
$diskspace = Get-DbaDiskSpace -SqlInstance $allservers -Detailed
$diskspace | Where PercentFree -lt 20

#endregion

#region testing backups

Get-Help Test-DbaLastBackup -Online
Import-Module SqlServer
Invoke-Item (Get-Item SQLSERVER:\SQL\LOCALHOST\DEFAULT).DefaultFile

Test-DbaLastBackup -SqlServer localhost | Out-GridView
Test-DbaLastBackup -SqlServer localhost -Destination sql2016\vnext -VerifyOnly | Out-GridView

#endregion

#region VLFs

$allservers | Test-DbaVirtualLogFile | Where-Object {$_.Count -ge 50} | Sort-Object Count -Descending | Out-GridView

#endregion

#region databasespace

# Get Db Free Space AND write it to disk
Get-DbaDatabaseFreespace -SqlServer $instance
Get-DbaDatabaseFreespace -SqlServer $instance -IncludeSystemDBs | Out-DbaDataTable | Write-DbaDataTable -SqlServer $instance -Table tempdb.dbo.DiskSpaceExample
Get-DbaDatabaseFreespace -SqlServer $instance -IncludeSystemDBs | Out-DbaDataTable | Write-DbaDataTable -SqlServer $instance -Table tempdb.dbo.DiskSpaceExample -AutoCreateTable

# Run a lil query
Ssms.exe "C:\temp\tempdbquery.sql"

#endregion

#region blog posts turned commands

# Test/Set SQL max memory
$allservers | Get-DbaMaxMemory
$allservers | Test-DbaMaxMemory | Format-Table
$allservers | Test-DbaMaxMemory | Where-Object { $_.SqlMaxMB -gt $_.TotalMB } | Set-DbaMaxMemory -WhatIf
Set-DbaMaxMemory -SqlServer $instance -MaxMb 2048

# RecoveryModel
Test-DbaFullRecoveryModel -SqlServer sql2005
Test-DbaFullRecoveryModel -SqlServer sql2005 | Where { $_.ConfiguredRecoveryModel -ne $_.ActualRecoveryModel }

# Backup History!
Get-DbaBackupHistory -SqlServer $instance
Get-DbaBackupHistory -SqlServer $instance | Out-GridView
Get-DbaBackupHistory -SqlServer $instance -Databases AdventureWorks2012 | Format-Table -AutoSize

# Restore History!
Get-DbaRestoreHistory -SqlServer $instance | Out-GridView
 
#endregion

#region mindblown

# Find-DbaStoredProcdure
$allservers | Find-DbaStoredProcedure -Pattern dbatools
$allservers | Find-DbaStoredProcedure -Pattern dbatools | Select * | Out-GridView
$coupleservers | Find-DbaStoredProcedure -Pattern '\w+@\w+\.\w+'

# Remove dat orphan - by @sqlstad
Find-DbaOrphanedFile -SqlServer $instance
((Find-DbaOrphanedFile -SqlServer $instance -RemoteOnly | Get-ChildItem | Select -ExpandProperty Length | Measure-Object -Sum)).Sum / 1MB
Find-DbaOrphanedFile -SqlServer $instance -RemoteOnly | Remove-Item

# Reset-SqlAdmin
Reset-SqlAdmin -SqlServer $instance -Login sqladmin

#endregion

#region bits and bobs

# DbaStartupParameter
Get-DbaStartupParameter -SqlServer $instance
Get-DbaStartupParameter -SqlServer $new

# sp_whoisactive
Show-SqlWhoisActive -SqlServer $instance # -ShowOwnSpid -ShowSystemSpids

#endregion