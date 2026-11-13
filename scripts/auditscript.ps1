# Windows Server 2025 Security Audit
# Read-only audit script
# Creates a text report in C:\Temp

# Fungerar ej bra, stoppar efter Powershell 2.0, behöver felsökas/göras om. Prompt var "Create a safe audit script for Windows Server 2025"

$ReportPath = "C:\Temp\SecurityAudit_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"

if (!(Test-Path "C:\Temp")) {
    New-Item -ItemType Directory -Path "C:\Temp" | Out-Null
}

function Add-Section {
    param($Title)

    Add-Content $ReportPath ""
    Add-Content $ReportPath "================================================="
    Add-Content $ReportPath $Title
    Add-Content $ReportPath "================================================="
}

Add-Content $ReportPath "Windows Server Security Audit"
Add-Content $ReportPath "Server: $env:COMPUTERNAME"
Add-Content $ReportPath "Date: $(Get-Date)"

# OS Information
Add-Section "Operating System"

Get-ComputerInfo |
Select-Object WindowsProductName,
              WindowsVersion,
              OsBuildNumber |
Out-String |
Add-Content $ReportPath

# SMBv1
Add-Section "SMBv1 Status"

try {
    Get-SmbServerConfiguration |
    Select-Object EnableSMB1Protocol |
    Out-String |
    Add-Content $ReportPath
}
catch {
    Add-Content $ReportPath "Unable to determine SMBv1 status."
}

# PowerShell Version
Add-Section "PowerShell Version"

$PSVersionTable | Out-String | Add-Content $ReportPath

# PowerShell 2.0
Add-Section "PowerShell 2.0 Feature"

Get-WindowsOptionalFeature -Online |
Where-Object FeatureName -match "PowerShellV2" |
Out-String |
Add-Content $ReportPath

# TLS Protocols
Add-Section "TLS Configuration"

$TLSPath = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols"

if (Test-Path $TLSPath) {
    Get-ChildItem $TLSPath |
    Select-Object PSChildName |
    Out-String |
    Add-Content $ReportPath
}

# Firewall
Add-Section "Firewall Profiles"

Get-NetFirewallProfile |
Select-Object Name,
              Enabled,
              DefaultInboundAction,
              DefaultOutboundAction |
Out-String |
Add-Content $ReportPath

# NetBIOS
Add-Section "NetBIOS Configuration"

Get-WmiObject Win32_NetworkAdapterConfiguration |
Where-Object {$_.IPEnabled} |
Select-Object Description,
              TcpipNetbiosOptions |
Out-String |
Add-Content $ReportPath

# LLMNR
Add-Section "LLMNR"

$LLMNR = Get-ItemProperty `
"HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient" `
-ErrorAction SilentlyContinue

if ($LLMNR) {
    $LLMNR | Out-String | Add-Content $ReportPath
}
else {
    Add-Content $ReportPath "No LLMNR policy configured."
}

# Installed Features
Add-Section "Installed Windows Features"

Get-WindowsFeature |
Where-Object {$_.InstallState -eq "Installed"} |
Select-Object Name |
Sort-Object Name |
Out-String |
Add-Content $ReportPath

# Running Services
Add-Section "Running Services"

Get-Service |
Where-Object {$_.Status -eq "Running"} |
Sort-Object DisplayName |
Select-Object DisplayName, StartType |
Out-String |
Add-Content $ReportPath

# Potentially Legacy Services
Add-Section "Potentially Legacy Services"

$LegacyServices = @(
    "Spooler",
    "RemoteRegistry",
    "SSDPSRV",
    "upnphost",
    "TlntSvr"
)

foreach ($Service in $LegacyServices) {

    $Result = Get-Service -Name $Service -ErrorAction SilentlyContinue

    if ($Result) {

        [PSCustomObject]@{
            Service = $Result.Name
            Status  = $Result.Status
        } |
        Out-String |
        Add-Content $ReportPath
    }
}

# Local Administrators
Add-Section "Local Administrators"

Get-LocalGroupMember Administrators |
Out-String |
Add-Content $ReportPath

# Listening Ports
Add-Section "Listening Network Ports"

Get-NetTCPConnection -State Listen |
Select-Object LocalAddress,
              LocalPort |
Sort-Object LocalPort |
Out-String |
Add-Content $ReportPath

Write-Host ""
Write-Host "Audit complete."
Write-Host "Report saved to:"
Write-Host $ReportPath


# Active Directory and Group Policy Information

Import-Module ActiveDirectory
Import-Module GroupPolicy -ErrorAction SilentlyContinue

Add-Section "Active Directory Domain Information"

Get-ADDomain |
Select-Object DNSRoot,
              DomainMode,
              RIDMaster,
              PDCEmulator,
              InfrastructureMaster |
Out-String |
Add-Content $ReportPath

Add-Section "Default Domain Password Policy"

# Password Policy
Get-ADDefaultDomainPasswordPolicy |
Select-Object `
MinPasswordLength,
MaxPasswordAge,
PasswordHistoryCount,
LockoutDuration,
LockoutThreshold,
ComplexityEnabled,
ReversibleEncryptionEnabled |
Out-String |
Add-Content $ReportPath

#Check domain Admins

Add-Section "Domain Admin Membership"

Get-ADGroupMember "Domain Admins" |
Select-Object Name,ObjectClass |
Out-String |
Add-Content $ReportPath

# Check Enterprise Admins

Add-Section "Enterprise Admin Membership"

Get-ADGroupMember "Enterprise Admins" -ErrorAction SilentlyContinue |
Select-Object Name,ObjectClass |
Out-String |
Add-Content $ReportPath

# Check Administrators

Add-Section "Builtin Administrators"

Get-ADGroupMember "Administrators" |
Select-Object Name,ObjectClass |
Out-String |
Add-Content $ReportPath

# Check users with Password Never Expires

Add-Section "Password Never Expires"

Get-ADUser -Filter * `
-Properties PasswordNeverExpires |
Where-Object {$_.PasswordNeverExpires -eq $true} |
Select-Object Name,SamAccountName |
Out-String |
Add-Content $ReportPath

# Check inactive users

Add-Section "Inactive Users Over 90 Days"

Search-ADAccount `
-AccountInactive `
-TimeSpan 90.00:00:00 `
-UsersOnly |
Select-Object Name,SamAccountName |
Out-String |
Add-Content $ReportPath

# Check disabled users

Add-Section "Disabled Users"

Search-ADAccount -AccountDisabled -UsersOnly |
Select-Object Name,SamAccountName |
Out-String |
Add-Content $ReportPath

# Check users with Kerberos DES enabled

Add-Section "Kerberos DES Enabled Accounts"

Get-ADUser -Filter * `
-Properties UseDESKeyOnly |
Where-Object {$_.UseDESKeyOnly -eq $true } |
Select-Object Name |
Out-String |
Add-Content $ReportPath

# Check service accounts

Add-Section "Service Accounts"

Get-ADUser -Filter * `
-ServicePrincipalName "*" |
Select-Object Name,SamAccountName |
Out-String |
Add-Content $ReportPath

# Check computer accounts

Add-Section "Computer Accounts"

Get-ADComputer -Filter * |
Select-Object Name,Enabled |
Sort-Object Name |
Out-String |
Add-Content $ReportPath

# Check inactive computer accounts

Add-Section "Inactive Computers Over 90 Days"

Search-ADAccount `
-AccountInactive `
-TimeSpan 90.00:00:00 `
-ComputersOnly |
Select-Object Name |
Out-String |
Add-Content $ReportPath

# Check Organizational Units

Add-Section "Organizational Units"

Get-ADOrganizationalUnit -Filter * |
Select-Object Name,DistinguishedName |
Sort-Object Name |
Out-String |
Add-Content $ReportPath

# Group audit

Add-Section "Security Groups"

Get-ADGroup -Filter * |
Select-Object Name,GroupScope |
Sort-Object Name |
Out-String |
Add-Content $ReportPath

# GPO audit

Add-Section "Group Policy Objects"

Get-GPO -All |
Select-Object DisplayName,GpoStatus |
Sort-Object DisplayName |
Out-String |
Add-Content $ReportPath

# Unlinked GPOs

Add-Section "Unlinked GPOs"

Get-GPO -All |
Where-Object {
    (Get-GPOReport -Guid $_.Id -ReportType XML) -notmatch "<LinksTo>"
} |
Select-Object DisplayName |
Out-String |
Add-Content $ReportPath

# SYSVOL health

Add-Section "SYSVOL Replication"

dcdiag /test:sysvolcheck |
Out-String |
Add-Content $ReportPath

# DCDIAG health check

Add-Section "Domain Controller Health"

dcdiag /q |
Out-String |
Add-Content $ReportPath

# CIS-Style quick Risk summary

Add-Section "Security Findings Summary"

$SMB = (Get-SmbServerConfiguration).EnableSMB1Protocol

if ($SMB) {
    Add-Content $ReportPath "[HIGH] SMBv1 Enabled"
}

$PNE = Get-ADUser -Filter * -Properties PasswordNeverExpires |
       Where-Object {$_.PasswordNeverExpires}

Add-Content $ReportPath "[INFO] Password Never Expires Accounts: $($PNE.Count)"

$DA = Get-ADGroupMember "Domain Admins"

Add-Content $ReportPath "[INFO] Domain Admin Count: $($DA.Count)"

$InactiveUsers = Search-ADAccount `
-AccountInactive `
-TimeSpan 90.00:00:00 `
-UsersOnly

Add-Content $ReportPath "[INFO] Inactive Users: $($InactiveUsers.Count)"