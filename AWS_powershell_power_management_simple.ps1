#
# AWS PowerOn/Off Schedular
# Tag Name: Power_Options
# Tag values: PowerOn,Mon:5,Tue:5,Wed:6,Thu:6,Fri:6,Sat:6,Sun:6;PowerOff,Mon:18,Tue:18,Wed:22,Thu:18,Fri:18,Sat:19,Sun:19;Notify,user_example@example.com,user_example2@example.com
#
# Requires AWS plugin: https://aws.amazon.com/powershell/
# Set-AWSCredentials -AccessKey <access key> -SecretKey <secret key> -Storeas <profile name>
# Full instructions found http://i-script-stuff.electric-horizons.com/
#
#


#profiles to check
$profile_list = ("Example_1")


#Just a quick check for powershell 3.0 and older changes the method of plugin loading.
if($PSVersionTable.PSVersion.Major -ge 4) {
Import-Module AWSPowerShell
} else {
Import-Module "C:\Program Files (x86)\AWS Tools\PowerShell\AWSPowerShell\AWSPowerShell.psd1"
}

 
#Actual Engine.
#Parses through profiles and regions.
foreach($profile in $profile_list) {
Set-AWSCredentials -ProfileName $profile
$region_list = Get-AWSRegion | select -expandproperty Region

	foreach($region in $region_list) {
	$Instance_list = Get-EC2Instance -region $region |select -expandproperty instances

	$VPC_list = Get-EC2Vpc -Region $region
		foreach ($VPC in $VPC_list) {
			$Instance_list | Where-Object {$_.VpcId -eq $VPC.VpcId} | foreach-object {
			$Instance_name = ($_.Tags | Where-Object {$_.Key -eq 'Name'}).Value
			$power_Action = $NULL
				if($Power_Options = ($_.Tags | Where-Object {$_.Key -eq 'Power_Options'}).Value) {
				if($_.State.Name -like "running") {
				stop-EC2Instance -InstanceId $_.InstanceId -Region $region
				} else {
				Start-EC2Instance -InstanceId $_.InstanceId -Region $region
				}
				}
			}
		}
	}
}