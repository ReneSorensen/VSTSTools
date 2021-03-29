[CmdletBinding()]
param()

# Debug values
$workingDir = "C:\GIT\TestEge\hooks"
$includeFiles = "[`".sql`"]"
$logFilesFolder = "C:\Temp"
$failIfNothing = "Yes"

$workingDir = Get-VstsInput -Name workingdir -Require
$includeFiles = Get-VstsInput -Name includefiles -Require
$logFilesFolder = Get-VstsInput -Name logfilesfolder -Require
$failIfNothing = Get-VstsInput -Name failIfNothing -Require

$includeTypes = @()
$ExecutedFiles = @()
$FilesToBeExecuted = @()
$Files = @()
$dateformat =  Get-Date -Format "yyyyMMdd#HHmmss"
$failed = $false

$includeTypes = $includeFiles | ConvertFrom-Json
Write-Host "Type of files to executed: $($includeTypes)"
Write-Host "Log files are written to:  $($logFilesFolder)"
if( ($null -eq $failIfNothing) -or 
($failIfNothing -like "") -or 
($failIfNothing -like "false") -or 
	($failIfNothing -like "no")){
	$failIfNothing = $false
	Write-Host "Will not fail if no files"
}else{
	$failIfNothing = $true
	Write-Host "Will fail if no files"
}

# For more information on the VSTS Task SDK:
# https://github.com/Microsoft/vsts-task-lib
Trace-VstsEnteringInvocation $MyInvocation
try { 
	Write-Host "Get files or file and put them in array, workdir: $($workingDir)"
    if(Test-Path $workingDir -pathType container){
		$Files = @(Get-ChildItem -Recurse -Path $workingDir | Where-Object { $includeTypes -contains $_.Extension } | Sort-Object | % {
			'@' + $_.Fullname
		})
		# Set working directory
		Set-Location -LiteralPath  $workingDir
	} 
	elseif(Test-Path $workingDir -pathType leaf){
		$Files = @('@' + (Split-Path $workingDir -leaf))
		# Set working directory
		Set-Location -LiteralPath  (Split-Path -Path $workingDir)
	}
	if ($null -eq $Files) {
		$Files = @()
		Write-Host "Files was null!"
	}
	if($Files.Length -eq 0 ){
		if ($failIfNothing){
			Write-Error "ERROR! no files to be executed"
			$failed = $true
		} else {
			Write-Warning "WARNING! no files to be executed"
		}
		exit
	}
	Write-Host "List of files:`n$($Files)"
	$FilesToBeExecuted = $Files

	ForEach ($f in $Files){
		# Run execution of file
		Write-Host "File to be executed: $($f)"
		$filename = Split-Path $f -leaf
		$logFile = [System.IO.Path]::Combine($logFilesFolder,$("{0}#$dateformat.log" -f $filename ))

		Write-Host "Log file: " $logFile
		$stmt  = "set hea off`n"
		$stmt += "set errorlogging on`n"
		$stmt += "set sqlblanklines on`n" # This should remove SP2-0042: unknown command "<command after blank line>" - rest of line ignored.
		$res = ($stmt | sqlplus /nolog $f )
		Write-Host "Result: " $res
		Write-Output $res | add-content $logFile
		if(($res -Match "ORA-") -or ($LastExitCode) -or ($res -Match "SP2-0310") -or ($res -Match "SP2-0734")){
			Write-Error ("Error has occurred in script $($f)")
			$failed = $true
			break
		} else {
			$ExecutedFiles += $f
			$FilesToBeExecuted = $FilesToBeExecuted -ne $f
		}
	}
}
finally {
	Trace-VstsLeavingInvocation $MyInvocation
	if($Files.Length -gt 0) {
		Write-Host ("The following files where executed:`n$($ExecutedFiles)")
		if($failed -or ($LastExitCode)){
			Write-Error ("ERROR the following files where not executed:`n$($FilesToBeExecuted)")
			exit 1
		}
	}
	Write-Host ("Job finish and number of files executed: $($ExecutedFiles.Length)")
	if ($failed){
		Write-Host "Returning 1 meaning it failed"
		exit 1
	}
}