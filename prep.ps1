# open google on a specific page
Get-Process *skype* | Stop-Process
Get-Process *pidgin* | Stop-Process
Get-Process *slack* | Stop-Process

# Copy-SqlSpConfigure
Copy-SqlSpConfigure -Source sql2008 -Destination sql2016 -Configs DefaultBackupCompression, IsSqlClrEnabled

Set-DbaMaxMemory sql2016\vnext -MaxMb 1024

cls