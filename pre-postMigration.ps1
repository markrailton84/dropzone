# variable assignment

# use below arguemnt
$argMigrationStage = $args[0]

$logLocationInput = $(Get-Location) # this location when using az cli invoke command will position file in "c:\azure"
$instanceName = $env:computername
$bootType = $env:firmware_type
$osVersion = $(Get-WmiObject -class Win32_OperatingSystem).caption
#$guidGen = $([guid]::NewGuid().ToString())
#$guidGenShort = $guidGen.substring(0,8)
$dateTimeStamp = $(Get-Date -Format "dd-MM-yyyy" )

# Define log location

$logLocation = New-Item -Path $logLocationInput -Name "$argMigrationStage-$instanceName-$dateTimeStamp.log" -ItemType "file" -Value ""

# computername stamp

Write-Output "Computer Name: $instanceName" | Out-File -Append $logLocation
Write-Output "" | Out-File -Append $logLocation
Write-Output "$osVersion" | Out-File -Append $logLocation

# Fetch Domain Name (FQDN)

$fqdn = ([System.Net.Dns]::GetHostByName(($env:computerName))).Hostname

Write-Output "" | Out-File -Append $logLocation
Write-Output "FQDN: $fqdn" | Out-File -Append $logLocation

# get boot type e.g. bios(legacy) or UEFI

Write-output "Boot Type" | Out-File -Append $logLocation
Write-output $bootType | Out-File -Append $logLocation
Write-Output "" | Out-File -Append $logLocation

# check if vmstorfl.sys exists - required for ASR to migrate VM's

If (Test-Path -Path C:\Windows\system32\drivers\vmstorfl.sys) {
    Write-Output "vmstorfl.sys exists" | Out-File $logLocation -append
}
else{
    Write-Output "vmstorfl.sys doesn't exists" | Out-File $logLocation -append
}

# add a copy nested else statement to create dummy file: "copy nul c:\Windows\system32\drivers\vmstorfl.sys"

Write-Output "" | Out-File -Append $logLocation

# last reboot checker greater or equal to 30 days

$Today = Get-Date
$lastReboot = Get-WmiObject win32_operatingsystem | Select-Object csname, @{LABEL='LastBootUpTime';EXPRESSION={$_.ConverttoDateTime($_.lastbootuptime)}}
$diffCheck = $Today.date - $lastReboot.lastbootuptime.date

if ($diffCheck.TotalDays -ge 30 ){
    Write-Output "Instance has not been rebooted for 30 days +" | Out-File $logLocation -append
}
else{
    Write-Output 'Last reboot in days:' $diffCheck.TotalDays | Out-File $logLocation -append
}

Write-Output "" | Out-File -Append $logLocation

# san policy checker - online all

$sanpolicy = "san" | diskpart
"exit" | diskpart
if ($sanpolicy | Select-String "Online All") {
    Write-Output  "San Policy is Online All" | Out-File -Append $logLocation
}
else {
    Write-Output  "San Policy is not online" | Out-File -Append $logLocation
}

# boot disk checker

$bootchecker = "list disk" | diskpart
"exit" | diskpart
Write-Output $bootchecker | Out-File -Append $logLocation

# fetch disk info

$logicaldisks = Get-WmiObject Win32_Logicaldisk | Select-Object SystemName,DeviceID,@{Name="size(GB)"; Expression={[math]::round($_.size/1GB)}} | Format-Table -AutoSize | Out-File $logLocation -append

# fetch drive letters and output physical and logic sector sizes for each drive
  
$driveLetters = Get-PSDrive | Select-Object -ExpandProperty 'Name' | Select-String -Pattern '^[a-z]$'
foreach($i in $driveLetters) {Write-Output "Drive Letter: $i"; Write-output ""; fsutil fsinfo ntfsinfo $i":"; Write-output "" | select-string "Sector" | Out-File $logLocation -append}

# Check if there is disk encryption

$BLockerCheck = manage-bde -status
if (-Not($BLockerCheck | Select-String "Protection On")) {
    Write-Output  "Bitlocker is not enabled - no disks encrypted." | Out-File -Append $logLocation
} Else {
    Write-Output "Bitlocker is enabled - potential disks encrypted." | Out-File -Append $logLocation 
}
Write-Output "" | Out-File -Append $logLocation

# fetch networking related info

$ipAddressBound = Get-WmiObject Win32_NetworkAdapterConfiguration -Filter 'IPEnabled=TRUE' | Select-Object -ExpandProperty IPAddress | Where-Object { $_ -match '(\d{1,3}\.){3}\d{1,3}' } | Out-File $logLocation -append

$ConnectedNics = Get-WmiObject win32_networkadapter -filter "netconnectionstatus = 2" | Measure-Object
$NicsList = $ConnectedNics | Select-Object netconnectionid, name | Out-String
$NicsCount = $ConnectedNics.Count
Write-Output "Total Nics: $nicsCount" | Out-File -Append $logLocation
Write-Output "" | Out-File -Append $logLocation

# fetch vCPU

$vcpu = (Get-CimInstance -ClassName 'Win32_Processor' | Measure-Object -Property 'NumberOfCores' -Sum).Sum
Write-Output "vCPUs: $vcpu" | Out-File -Append $logLocation

# fetch RAM

$totalMemory = Get-CimInstance Win32_PhysicalMemory | Measure-Object -Property capacity -Sum | Foreach {"{0:N2}" -f ([math]::round(($_.Sum / 1GB),2))}
Write-Output "RAM: $totalMemory GB" | Out-File -Append $logLocation

# fetch total disk size
 
$diskCapacity = Get-WmiObject Win32_LogicalDisk | Select-Object DeviceID, @{'Name' = 'Total Disk Size (GB)'; Expression= { ($_.Size) / 1GB }}
Write-Output $diskCapacity | Out-File -Append $logLocation

# fetch used disk space

$usedSpace =  Get-WmiObject Win32_LogicalDisk | Select-Object DeviceID, @{'Name' = 'Used Disk Space (GB)'; Expression= { ($_.Size - $_.FreeSpace) / 1GB }}
Write-Output $usedSpace | Out-File -Append $logLocation

# fetch free disk space

$usedSpace =  Get-WmiObject Win32_LogicalDisk | Select-Object DeviceID, @{'Name' = 'Free Disk Space (GB)'; Expression= { ($_.FreeSpace) / 1GB }}
Write-Output $usedSpace | Out-File -Append $logLocation

# fetch dns addresses

$dnsNetworks = Get-WmiObject -Class Win32_NetworkAdapterConfiguration -Filter IPEnabled=TRUE -ErrorAction Stop
foreach($dnsNetwork in $dnsNetworks) {
    $DNSServers = $dnsNetwork.DNSServerSearchOrder
    $dnsNetworkName = $dnsNetwork.Description
    If(!$DNSServers) {
        $PrimaryDNSServer = "Notset"
        $SecondaryDNSServer = "Notset"
    } elseif($DNSServers.count -eq 1) {
        $PrimaryDNSServer = $DNSServers[0]
        $SecondaryDNSServer = "Notset"
    } else {
        $PrimaryDNSServer = $DNSServers[0]
        $SecondaryDNSServer = $DNSServers[1]
    }
    If($dnsNetwork.DHCPEnabled) {
        $IsDHCPEnabled = $true
    }
    
    $OutputObj  = New-Object -Type PSObject
    $OutputObj | Add-Member -MemberType NoteProperty -Name PrimaryDNSServers -Value $PrimaryDNSServer
    $OutputObj | Add-Member -MemberType NoteProperty -Name SecondaryDNSServers -Value $SecondaryDNSServer
    $OutputObj | Add-Member -MemberType NoteProperty -Name IsDHCPEnabled -Value $IsDHCPEnabled
}

$OutputObj | Out-File -Append $logLocation
$gatewayAddress = $(Get-WmiObject -Class Win32_IP4RouteTable | where { $_.destination -eq '0.0.0.0' -and $_.mask -eq '0.0.0.0'} | select-object -ExpandProperty nexthop)
$gatewayCheck = $(Test-Connection (Get-WmiObject -Class Win32_IP4RouteTable | where { $_.destination -eq '0.0.0.0' -and $_.mask -eq '0.0.0.0'} | select-object -ExpandProperty nexthop) -Quiet -Count 1)
if ($gatewayCheck -eq "True"){
    Write-Output "Gateway Reachable - $gatewayAddress" | Out-File -Append $logLocation
}
else{
    Write-Output "Gateway Unreachable - $gatewayAddress" | Out-File -Append $logLocation
}

# Get .NET Framework versions installed

Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP' -Recurse | Get-ItemProperty -Name version -EA 0 | Where { $_.PSChildName -Match '^(?!S)\p{L}'} | Select PSChildName, version | out-file $logLocation -append

# fetch running services

$RunningServices = Get-Service | Where-Object {$_.Status -eq "Running"} | Select-Object status, name| Out-File $logLocation -append
