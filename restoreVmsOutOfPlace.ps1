# This script loops through feeder csv file with one VM per line and restores the VM out of place to esx server and datastore specified on line
# Prefix added to restored VM is DRTest_ but can be changed. See $prefix variable
# Change the $cs and $hypervisor variables to match your environment
# If using domain credentials then use format user@domain.example
# Create folder C:\cvscripts and run script from this folder

<#
This is an example input csv file

vmname,esx,datastore
mysql,esx2.cv.lab,esx2_DR_Target
JustATest,esx2.cv.lab,esx2_DR_Target
vmwinsqldr5,esx2.cv.lab,esx2_DR_Target
NotARealVM,esx2.cv.lab,esx2_DR_Target
#>

# Setup logging
$Logfile = "C:\cvScripts\restoreVmsOutOfPlaceSimple.log"

# Specify your CommServe URL here
$cs = "http://commserve1.cv.lab"

# Specify the client name for the HyperVisor here. NOTE: This is not the hostname of the VCenter server but rather the client name as defined in Commvault.
$hypervisor = 'ESX2'

# Add prefix to VM being restored for new name. For out-of-place restore
$prefix = 'DRTest_'

# Get list of VM's from file
$vms = Import-Csv -path C:\cvScripts\vmList.csv


function WriteLog
{

    Param ([string]$LogString)
    $Stamp = (Get-Date).toString("yyyy/MM/dd HH:mm:ss")
    $LogMessage = "$Stamp $LogString"
    Add-content $LogFile -value $LogMessage

}

# Let's get credentials from the user to login to Commvault. Needs to be an admin
$credential = Get-Credential
$username = $credential.UserName
$password = $credential.GetNetworkCredential().password

# password needs to be in base64 format
$password = [System.Text.Encoding]::UTF8.GetBytes($password)
$password = [System.Convert]::ToBase64String($password)

$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("Accept", "application/json")
$headers.Add("Content-Type", "application/json")
$body = "{`n  `"password`": `"$password`",`n  `"username`": `"$username`",`n  `"timeout`" : 30`n}"

# Login
$response = Invoke-RestMethod "$cs/webconsole/api/Login" -Method 'POST' -Headers $headers -Body $body

# need to extract the token
$token = $response | Select-Object -ExpandProperty token
# the first five characters need to be removed to get just the token
$token = $token.substring(5)

# Now that we have a token we can do things
$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("Accept", "application/json")
$headers.Add("Authtoken", "$token")
$headers.Add("Content-Type", "application/json")


# Get list of VM's in CommCell
$ccVms = Invoke-RestMethod "$cs/webconsole/api/VM" -Method 'GET' -Headers $headers


foreach ($vm in $vms) {
    # Get the values from each line in the csv file
    $vmname = $vm | Select-Object -ExpandProperty "vmname"
    $esx = $vm | Select-Object -ExpandProperty "esx"
    $datastore = $vm | Select-Object -ExpandProperty "datastore"
    
    # Get GUID for VM
    $vmGuid = $ccVMs.vmStatusInfoList | Where-Object name -eq $vmname | Select-Object -ExpandProperty strGUID

    if ($null -ne $vmGuid) {
        
        # Provide VM restore options here.
        $body = "<Api_VMRestoreReq powerOnVmAfterRestore =`"true`" passUnconditionalOverride=`"true`" inPlaceRestore=`"false`">`n<destinationClient clientName=`"$hypervisor`" />`n<destinationInfo>`n<vmware esxHost=`"$esx`" dataStore=`"$datastore`" resourcePool=`"`" newName=`"$prefix$vmname`" />`n</destinationInfo>`n</Api_VMRestoreReq>"
        
        # Restore VM
        $response = Invoke-RestMethod "$cs/webconsole/api/v2/vsa/vm/$vmGuid/recover" -Method 'POST' -Headers $headers -Body $body -ContentType 'application/xml'
        #$response | ConvertTo-Json -depth 10
        $jobid = $response | Select-Object -ExpandProperty jobIds
        Write-Host "VM: $vmname with $vmGuid out-of-place restore to $prefix$vmname started with JobID: $jobid"
        WriteLog "VM: $vmname with $vmGuid out-of-place restore to $prefix$vmname started with JobID: $jobid"

    } else {

        Write-Host "VM: $vmname not found in CommCell"
        WriteLog "VM: $vmname not found in CommCell"

    }

}