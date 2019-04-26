[CmdletBinding()]
param()

# Find the hashId for the commit, using tag or id
function GetGitHashId([String] $revArg) {
	Write-Host "GetGitHashId revArg: " $revArg
    try {
        if(($revArg -eq $Null) -or ($revArg -eq '')) {
            Write-Verbose "revArg has no value"
            return $Null
        }
		Write-Host "##[command]"git rev-parse $revArg
        $a = git rev-parse $revArg;
        if (-not $? -Or $a -eq $Null) {
            Write-Verbose "Unknown revision or path not in the working tree"
            return $Null
        }
        Write-Host "HashId for $($revArg) is " $a
        return $a
    } catch {
        throw ("Error: Something went wrong. Please check the logs.")
    }
}

# Copy file to destination
function CopyFileToDestination([String] $fileArg, [String] $destinationArg) {
	Write-Host "CopyFileToDestination File: " $fileArg " Destination: "$destinationArg
	if($shouldFlatten)
	{
		New-Item -ItemType Directory -Path "$destinationArg" -Force | out-null
		Copy-Item $fileArg -Destination "$destinationArg"
	}
	else
	{
		$destinationPath = join-path $destinationArg (Split-Path -parent $fileArg);
		Write-Verbose $destinationPath
		New-Item -ItemType Directory -Path "$destinationPath" -Force | out-null
		Copy-Item $fileArg -Destination "$destinationPath" -recurse -container;
	}
}

# Delete file, insert removing command
function DeleteFileFromDestination([String] $deleteFileArg, [String] $deleteDestinationArg) {
	Write-Host "DeleteFileFromDestination File: " $deleteFileArg " Destination: "$deleteDestinationArg
	$deleteText = "Remove-Item $($deleteFileArg) -ErrorAction Ignore"
	Write-Host "##[command]"$deleteText
	if (Test-Path $deleteDestinationArg\$FilesToBeDelete) {
		Add-Content -Path "$deleteDestinationArg\$FilesToBeDelete" -Value $deleteText
	} else {
		New-Item -ItemType Directory -Path "$deleteDestinationArg" -Force | out-null
		Set-Content -Path "$deleteDestinationArg\$FilesToBeDelete" -Value $deleteText -Force
	}
}

$workingDir = Get-VstsInput -Name workingdir -Require
$currentCommitInput = Get-VstsInput -Name currentcommit
$destination = Get-VstsInput -Name destination -Require
$changeTypeInput = Get-VstsInput -Name changeType -Require
$gitTag = Get-VstsInput -Name gittag -Require
$shouldFlattenInput = Get-VstsInput -Name flatten
$useBranchAsRoot = Get-VstsInput -Name branchAsRoot
$changeType = $changeTypeInput.split(",")
[boolean]$shouldFlatten = [System.Convert]::ToBoolean($shouldFlattenInput)

$FilesToBeDelete = "FilesToBeDelete.ps1"

if (!(Get-VstsTaskVariable -Name "System.AccessToken")) {
    throw ("OAuth token not found. Make sure to have 'Allow Scripts to Access OAuth Token' enabled in the definition.")
}

# currentCommit is empty use HEAD
if(($currentCommitInput -eq $Null) -or ($currentCommitInput -eq '')) {
		$currentCommit = "HEAD"
} else {
	$currentCommit = $currentCommitInput
}

# For more information on the VSTS Task SDK:
# https://github.com/Microsoft/vsts-task-lib
Trace-VstsEnteringInvocation $MyInvocation
try {
	Write-Host "Setting working directory to '$workingDir'."
	Set-Location $workingDir
	Write-Host "Current commit is $currentCommit"
	
	git config core.quotepath off
	[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
	
	# Get the commit SHA-1 hash ID from $currentCommit
	Set-Variable -name new_commit_hash -Value (GetGitHashId -revArg "$($currentCommit)")
	Write-Host "New commit head hashid: " $new_commit_hash

	# Get the commit SHA-1 hash ID from tag
	Set-Variable -name old_commit_hash -Value (GetGitHashId -revArg "$($gitTag)")
	# If commit not have been found, get the first commit form repo
	if(($old_commit_hash -eq $Null) -or ($old_commit_hash -eq '') -and (-not ([string]::IsNullOrEmpty($useBranchAsRoot)))) {
        Write-Host "If old commit not have been found try with TAG: " $useBranchAsRoot
		Set-Variable -name old_commit_hash -Value (GetGitHashId -revArg "$($useBranchAsRoot)")
	}
	if(($old_commit_hash -eq $Null) -or ($old_commit_hash -eq '')) {
        Write-Host "TAG: $($useBranchAsRoot) did not work using first commit"
		$old_commit_hash = git rev-list --max-parents=0 $currentCommit
	}
	Write-Host "Old commit TAG hashid: " $old_commit_hash

	# create Changed and Deleted folder
	New-Item -ItemType Directory -Path "$destination\Deleted" -Force | out-null
	New-Item -ItemType Directory -Path "$destination\Changed" -Force | out-null
	Write-Host "Create Changed and Deleted folder"

	
	# Diff between the two commits
	Write-Host "##[command]"git diff --name-status "$old_commit_hash $new_commit_hash"
	git diff --name-status $old_commit_hash $new_commit_hash | foreach {
		$item = @();
		$item = $_.Split([char]0x0009);
		Write-Host $item
		if(($item.length -gt 1) -and ($changeType.Contains($item[0].Substring(0,1)))) {
			if($item[0].Contains("D")){
				DeleteFileFromDestination -deleteFileArg $item[1] -deleteDestinationArg "$destination\Deleted"
			} elseif($item[0].Contains("R")){
				CopyFileToDestination -fileArg $item[2] -destinationArg "$destination\Changed"
				DeleteFileFromDestination -deleteFileArg $item[1] -deleteDestinationArg "$destination\Deleted"
			} else {
				CopyFileToDestination -fileArg $item[1] -destinationArg "$destination\Changed"
			}
		}
	}
	
} finally {
	Trace-VstsLeavingInvocation $MyInvocation
	if ($LastExitCode -ne 0) { 
		Write-Error "Something went wrong. Please check the logs."
    }
}
