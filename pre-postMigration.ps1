# variable assignment

# use below arguemnt
$argMigrationStage = $args[0]

$logLocationInput = $(Get-Location) # this location when using az cli invoke command will position file in "c:\azure"
$instanceName = $env:computername
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

# fetch running services

$RunningServices = Get-Service | Where-Object {$_.Status -eq "Running"} | Select-Object status, name| Out-File $logLocation -append