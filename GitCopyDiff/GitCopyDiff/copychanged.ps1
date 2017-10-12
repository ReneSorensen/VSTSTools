[CmdletBinding()]
param()

$workingDir = $env:SYSTEM_DEFAULTWORKINGDIRECTORY 
$currentCommit = $env:BUILD_SOURCEVERSION
$destination = Get-VstsInput -Name destination -Require
$changeTypeInput = Get-VstsInput -Name changeType -Require
$shouldFlattenInput = Get-VstsInput -Name flatten 
$changeType = $changeTypeInput.split(",")
[boolean]$shouldFlatten = [System.Convert]::ToBoolean($shouldFlattenInput)

if (!($env:SYSTEM_ACCESSTOKEN ))
{
    throw ("OAuth token not found. Make sure to have 'Allow Scripts to Access OAuth Token' enabled in the build definition.")
}
	
# For more information on the VSTS Task SDK:
# https://github.com/Microsoft/vsts-task-lib
Trace-VstsEnteringInvocation $MyInvocation
try {
	Write-Verbose "Setting working directory to '$workingDir'."
    Set-Location $workingDir
	Write-Verbose "Current commit is $currentCommit"
	
	git config core.quotepath off
	[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
	
	[System.Collections.ArrayList]$changes = @();
	write-host "##[command]"git log -m -1 --name-status --pretty="format:" $currentCommit
	
	git log -m -1 --name-status --pretty="format:" $currentCommit | foreach{
    $item = $_.Split([char]0x0009);
    if($changeType.Contains($item[0])){
		if($item[0].Contains("R")){
			$changes += ,$item[2];
		} else {
			$changes += ,$item[1];
		}
     }
	}
	
	Write-Verbose "Changed files are:"
	$changes | foreach { Write-Verbose $_ }
	
	IF($shouldFlatten)
	{
		$changes | foreach {
			Copy-Item $_ -Destination "$destination"
			}
	}
	else
	{
		$changes | foreach {
		$destinationPath = join-path $destination $_;
		New-Item -ItemType File -Path "$destinationPath" -Force | out-null
		Copy-Item $_ -Destination "$destinationPath" -recurse -container;
		}
	}
	
} finally {
    Trace-VstsLeavingInvocation $MyInvocation
	if ($LastExitCode -ne 0) { 
		Write-Error "Something went wrong. Please check the logs."
    }
}
