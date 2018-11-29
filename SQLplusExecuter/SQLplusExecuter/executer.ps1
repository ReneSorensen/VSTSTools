[CmdletBinding()]
param()

$workingDir = Get-VstsInput -Name workingdir -Require
$includeFiles = Get-VstsInput -Name includefiles -Require
$logFilesFolder = Get-VstsInput -Name logfilesfolder -Require

if (!($env:SYSTEM_ACCESSTOKEN )) {
    throw ("OAuth token not found. Make sure to have 'Allow Scripts to Access OAuth Token' enabled in the build definition.
			Also, give 'Project Collection Build Service' 'Contribute' and 'Create Tag' permissions - Cog -> Version Control -> {Select Repository/ies}")
}

$ExecutedFiles = @()
$FilesToBeExecute = @()
$Files = @()
$dateformat =  Get-Date -Format "yyyyMMdd#HHmmss"

# For more information on the VSTS Task SDK:
# https://github.com/Microsoft/vsts-task-lib
Trace-VstsEnteringInvocation $MyInvocation
try {
	# Get files or file and put them in array
    if(Test-Path $workingDir -pathType container){
		$Files = Get-ChildItem -Path $workingDir | Where-Object { $includeFiles -contains $_.Extension } | Sort-Object | % {
			'@' + $_.Name
		}
		# Set working directory
		Set-Location -Path $workingDir
	} 
	elseif(Test-Path $workingDir -pathType leaf){
		$Files = '@' + (Split-Path $workingDir -leaf)
		# Set working directory
		Set-Location -Path (Split-Path -Path $workingDir)
	}
	Write-Host "List of files:`n$($Files)"
	$FilesToBeExecute = $Files

	ForEach ($f in $Files){
		# Run execution of file
		Write-Host "File to be execute: $($f)"
		$logFile = [System.IO.Path]::Combine($logFilesFolder,$("{0}#$dateformat.log" -f $f ))
		#
		$stmt  = "set hea off`n"
		$stmt += "set errorlogging on`n"
		$res = ($stmt | sqlplus /nolog $f )
		Write-Host "Result: " $res
		Write-Output $res | add-content $logFile
		if($res -Match "Error"){
			Write-Error ("Error has occurred in script $($f)")
			break
		} else {
			$ExecutedFiles += $f
			$FilesToBeExecute = $FilesToBeExecute -ne $f
		}
	}
}
finally {
    Trace-VstsLeavingInvocation $MyInvocation
	if(($res -Match "Error") -or ($LastExitCode) -or ($FilesToBeExecute.Length > 0)){
		Write-Host $res
		Write-Host $LastExitCode 
		Write-Host $FilesToBeExecute.Length
		Write-Error ("ERROR`nthe following files where not executed:`n$($FilesToBeExecute)`nLog from database:`n$($res)")
		exit 1
	}
}
