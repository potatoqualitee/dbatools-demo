# Don't run everything, thanks @alexandair!
break

# Get version
Get-Module -Name dbatools

# talk about SqlServer vs SqlInstance

# K, go - localhost
Invoke-Item C:\localbackups
Restore-DbaDatabase -SqlInstance localhost -Path C:\localbackups\AdventureWorks2014_201702181415.bak

# It's relative
Restore-DbaDatabase -SqlInstance sql2016 -Path C:\localbackups\AdventureWorks2014_201702181415.bak -WithReplace -Verbose

Invoke-Item \\sql2016\c$\temp
Restore-DbaDatabase -SqlInstance sql2016 -Path C:\temp\AdventureWorks2014_201702181415.bak -WithReplace

# restore to different directories
Invoke-Item \\nas\sql\smalloladir\db1
Invoke-Item E:\crazyawesome
Restore-DbaDatabase -SqlInstance localhost -Path \\nas\sql\smalloladir\db1 -MaintenanceSolutionBackup -DestinationDataDirectory E:\crazyawesome -DestinationLogDirectory E:\crazyawesome\logs

# backups + piped restores
Invoke-Item \\sql2005\c$\backups
Get-DbaDatabase -SqlInstance sql2005 -NoSystemDb | Backup-DbaDatabase -BackupDirectory C:\backups
Get-DbaBackupHistory -SqlInstance sql2005 -Databases db_2005_CL80 -Last
Get-DbaBackupHistory -SqlInstance sql2005 -Databases db_2005_CL80 -Last | Restore-DbaDatabase -SqlInstance sql2005 -WithReplace


# Restore a whole Ola Hallengren style instance
Invoke-Item \\nas\sql\sql2016 
Get-ChildItem \\nas\sql\sql2016 | Restore-DbaDatabase -SqlInstance localhost

# RestoreTime which creates a STOPAT
Get-DbaBackupHistory -SqlInstance sql2005 -Databases db_2005_CL80 | Restore-DbaDatabase -SqlInstance sql2005 -RestoreTime (Get-Date).AddMinutes(-30) -WithReplace

# Pipe Get-DbaDatabase to Backup to Restore!
Get-DbaDatabase -SqlInstance sql2005 -Databases dumpsterfire4 | Backup-DbaDatabase -BackupDirectory \\dc\sql\test | Restore-DbaDatabase -SqlInstance sql2016 -WithReplace

# Then do a whole instance like that
Get-DbaDatabase -SqlInstance sql2005 -NoSystemDb | Backup-DbaDatabase -BackupDirectory \\dc\sql\test | Restore-DbaDatabase -SqlServer sql2016\vnext

# Check out the webpage
Start-Process https://dbatools.io/snowball