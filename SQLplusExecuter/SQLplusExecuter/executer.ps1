[CmdletBinding()]
param()

$workingDir = Get-VstsInput -Name workingdir -Require
$includeFiles = Get-VstsInput -Name includefiles -Require
$logFilesFolder = Get-VstsInput -Name logfilesfolder -Require

$includeTypes = @()
$ExecutedFiles = @()
$FilesToBeExecuted = @()
$Files = @()
$dateformat =  Get-Date -Format "yyyyMMdd#HHmmss"

$includeTypes = $includeFiles | ConvertFrom-Json
Write-Host "Type of files to executed: $($includeTypes)"

# For more information on the VSTS Task SDK:
# https://github.com/Microsoft/vsts-task-lib
Trace-VstsEnteringInvocation $MyInvocation
try {
	# Get files or file and put them in array
    if(Test-Path $workingDir -pathType container){
		$Files = Get-ChildItem -Path $workingDir | Where-Object { $includeTypes -contains $_.Extension } | Sort-Object | % {
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
	$FilesToBeExecuted = $Files

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
			$FilesToBeExecuted = $FilesToBeExecuted -ne $f
		}
	}
}
finally {
    Trace-VstsLeavingInvocation $MyInvocation
	if(($res -Match "Error") -or ($LastExitCode) -or ($FilesToBeExecuted.Length -gt 0)){
		Write-Host ("The following files where executed:`n$($ExecutedFiles)")
		Write-Error ("ERROR`nthe following files where not executed:`n$($FilesToBeExecuted)`nLog from database:`n$($res)")
		exit 1
	}
}
