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



$from = "helpdesk@example.com"
#SMTP server to use
$smtp = "mail.example.com"
$smtp_port = "25"

#Just a quick check for powershell 3.0 and older changes the method of plugin loading.
if($PSVersionTable.PSVersion.Major -ge 4) {
Import-Module AWSPowerShell
} else {
Import-Module "C:\Program Files (x86)\AWS Tools\PowerShell\AWSPowerShell\AWSPowerShell.psd1"
}

#converts AWS tag into an object and notes if an action should happen or not.
function action_object($power_options) {
$power_procedure = $power_options -split(";")
$Notify = $Null
$PowerOn = $False
$PowerOff = $False
	
	foreach($procedure in $power_procedure) {
	$action_queue = $procedure -split ","
		switch -case ($action_queue[0]) {
			"PowerOn" {
				for($i=1;$i -le ($action_queue.count); $i++) {
					if(time_action $action_queue[$i]) {
					$PowerOn = $True
					}
				}
			}
		
			"PowerOff" {
				for($i=1;$i -le ($action_queue.count); $i++) {
					if(time_action $action_queue[$i]) {
					$PowerOff = $True
					}
				}
			}
			
			"Notify" {
				for($i=1;$i -le ($action_queue.count); $i++) {
					if($action_queue[$i]) {
					
					$Notify += $action_queue[$i] + ","
					}
				}
			$Notify = $Notify.Substring(0,$Notify.Length-1)
			}
			
		}
	}

$Object = @{
PowerOn = $PowerOn
PowerOff =  $PowerOff
Notify = $Notify
}

return $Object	
}

#Parses the time segment of the AWS tag and returns true or false normally only called in action_object
function time_action($action_options) {
$action_timing = $action_options -split ":"
$day = Get-date -format ddd
$hour = get-date -format HH 

	if(($action_timing[0] -like $day) -and ($action_timing[1] -like $hour)){
	return $true
	} elseif (($action_timing[0] -like "weekdays") -and ($action_timing[1] -like $hour) -and (($day -notlike "Sat") -and ($day -notlike "Sun"))) {
	return $true
	} elseif (($action_timing[0] -like "allweek") -and ($action_timing[1] -like $hour)) {
	return $true
	} else {
	return $false
	}
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
				$power_action = action_object $Power_Options
				}
				
				if(($power_action.PowerOff)) {
					$subject_power_off = "Scheduled PowerOff of $instance_name has begun"
					$body_power_off = "The EC2 instance $instance_name has started"
					if($power_action.Notify) {
					Stop-EC2Instance -InstanceId $_.InstanceId -Region $region
					Send-MailMessage -from $from -To $power_action.Notify -Subject $subject_power_off -bodyashtml($body_power_off) -smtpServer "$smtp" -port "$smtp_port"
					} else {
					Stop-EC2Instance -InstanceId $_.InstanceId -Region $region
					}
				}
						
				if(($power_action.PowerON)) { 
				#Email Messages to send
				$subject_power_on = "Scheduled PowerOn of $instance_name has started"
				$body_power_on = "The EC2 instance $instance_name has started"
					if($power_action.Notify) {
					Start-EC2Instance -InstanceId $_.InstanceId -Region $region
					Send-MailMessage -from $from -To $power_action.Notify -Subject $subject_power_on -bodyashtml($body_power_on) -smtpServer "$smtp" -port "$smtp_port"
					} else {
					Start-EC2Instance -InstanceId $_.InstanceId -Region $region
					}
				}
			}
		}
	}
}