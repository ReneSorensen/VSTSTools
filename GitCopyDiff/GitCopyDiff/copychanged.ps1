[CmdletBinding()]
param()

# Copy file to destination
function CopyFileToDestination([String] $fileArg, [String] $destinationArg) {
	Write-Host "Copy file to destination - File: " $fileArg " Destination: "$destinationArg
	if($shouldFlatten)
	{
		New-Item -ItemType Directory -Path "$destinationArg" -Force | out-null
		Copy-Item -LiteralPath $fileArg -Destination "$destinationArg"
	}
	else
	{
		$destinationPath = join-path $destinationArg (Split-Path -parent $fileArg);
		Write-Verbose $destinationPath
		New-Item -ItemType Directory -Path "$destinationPath" -Force | out-null
		Copy-Item -LiteralPath $fileArg -Destination "$destinationPath" -recurse -container;
	}
}

# Delete file, insert deleted file from repo til the list
function DeleteFileFromDestination([String] $deleteFileArg, [String] $deleteDestinationArg) {
	Write-Host "Add " $deleteFileArg " to the file " $deletedFileList "DeleteFileFromDestination File:  Destination: "$deleteDestinationArg
	$deleteText = "$($textBeforeFile)$($deleteFileArg)$($textAfterFile)"
	Write-Host "##[command]"$deleteText
	if (Test-Path -LiteralPath $deleteDestinationArg\$deletedFileList) {
		Add-Content -LiteralPath "$deleteDestinationArg\$deletedFileList" -Value $deleteText
	} else {
		New-Item -ItemType Directory -Path "$deleteDestinationArg" -Force | out-null
		Set-Content -LiteralPath "$deleteDestinationArg\$deletedFileList" -Value $deleteText -Force
	}
}

function Initialize() {
	function InitializeVariables () {
		# Locally scoped variable
		$shouldFlattenInput = Get-VstsInput -Name flatten
		$changeTypeInput = Get-VstsInput -Name changeType -Require
		$currentCommitInput = Get-VstsInput -Name currentcommit
		# Script scoped variables
		$Script:subDir = Get-VstsInput -Name subDir -Require
		$Script:workingDir = Get-VstsInput -Name workingdir -Require
		$Script:destination = Get-VstsInput -Name destination -Require
		$Script:gitTag = Get-VstsInput -Name gittag -Require
		$Script:useBranchAsRoot = Get-VstsInput -Name branchAsRoot
		$Script:changeType = $changeTypeInput.split(",")
		[boolean]$Script:shouldFlatten = [System.Convert]::ToBoolean($shouldFlattenInput)
		$Script:deletedFileList = Get-VstsInput -Name nameOfFileDeletedList
		$Script:textBeforeFile = Get-VstsInput -Name textBeforeFile
		$Script:textAfterFile = Get-VstsInput -Name textAfterFile

		# currentCommitInput is empty use HEAD
		if(($Null -eq $currentCommitInput) -or ($currentCommitInput -eq '')) {
			$Script:currentCommit = "HEAD"
		} else {
			$Script:currentCommit = $currentCommitInput
		}
		Write-Host "Current commit is $currentCommit"
	}
	function CheckRequiredOptions () {
        # Throw an error if the OAuth token is not accessible
        if (!(Get-VstsTaskVariable -Name "System.AccessToken")) {
            throw ("OAuth token not found. Make sure to have 'Allow Scripts to Access OAuth Token' enabled in the definition.")
        }
    }
	function SetLocation () {
        Write-Host "Setting working directory to '$workingDir'."
        Set-Location -LiteralPath $workingDir
    }
    function ConfigureGit () {
        git config core.quotepath off
        [Console]::OutputEncoding = [System.Text.Encoding]::UTF8    
    }
	function InitializeCommitIds () {
		# Find the hashId for the commit, using tag or id
		function GetGitHashId([String] $revArg) {
			Write-Host "GetGitHashId revArg: " $revArg
			try {
				if(($Null -eq $revArg) -or ($revArg -eq '')) {
					Write-Verbose "revArg has no value"
					return $Null
				}
				Write-Host "##[command]"git rev-parse $revArg
				$a = git rev-parse $revArg;
				if (-not $? -Or $Null -eq $a) {
					Write-Verbose "Unknown revision or path not in the working tree"
					return $Null
				}
				Write-Host "HashId for $($revArg) is " $a
				return $a
			} catch {
				throw ("Error: Something went wrong. Please check the logs.")
			}
		}		

		# Get the commit SHA-1 hash ID from $currentCommit
		Set-Variable -name new_commit_hash -Value (GetGitHashId -revArg "$($currentCommit)") -Scope Script
		Write-Host "New commit head hashid: " $new_commit_hash

		# Get the commit SHA-1 hash ID from tag
		Set-Variable -name old_commit_hash -Value (GetGitHashId -revArg "$($gitTag)") -Scope Script

		# If commit not have been found, get the first commit form repo
		if(($Null -eq $old_commit_hash) -or ($old_commit_hash -eq '') -and (-not ([string]::IsNullOrEmpty($useBranchAsRoot)))) {
			Write-Host "If old commit not have been found try with branchAsRoot as TAG: " $useBranchAsRoot
			Set-Variable -name old_commit_hash -Value (GetGitHashId -revArg "$($useBranchAsRoot)") -Scope Script
		}
		if(($Null -eq $old_commit_hash) -or ($old_commit_hash -eq '')) {
			Write-Host "GitTag and branchAsRoot did not work, using the first commit created for this repo"
			Write-Host "##[command]"git rev-list --max-parents=0 "$currentCommit"
			Set-Variable -name old_commit_hash -Value (git rev-list --max-parents=0 $currentCommit) -Scope Script
		}
		Write-Host "Old commit TAG hashid: " $old_commit_hash
    }
	function InitializeFolders () {
		# create Changed and Deleted folder
		New-Item -ItemType Directory -Path "$destination\Deleted" -Force | out-null
		New-Item -ItemType Directory -Path "$destination\Modified" -Force | out-null
		New-Item -ItemType Directory -Path "$destination\Added" -Force | out-null
		New-Item -ItemType Directory -Path "$destination\Changed" -Force | out-null
		Write-Host "Create Changed, Modified, Added and Deleted folders"
	}
	InitializeVariables
    CheckRequiredOptions
    SetLocation
    ConfigureGit
    InitializeCommitIds
	InitializeFolders
}

function HandleDiff () {
	# Diff between the two commits
	Write-Host "##[command]"git diff --name-status "$old_commit_hash $new_commit_hash"
	git diff --name-status $old_commit_hash $new_commit_hash $subDir | ForEach-Object {
		$item = @();
		$item = $_.Split([char]0x0009);
		Write-Host $item
		if(($item.length -gt 1) -and ($changeType.Contains($item[0].Substring(0,1)))) {
			switch ($item[0].Substring(0,1)) {
				"D" { # Deleted
					DeleteFileFromDestination -deleteFileArg $item[1] -deleteDestinationArg "$destination\Deleted"
				}
				"R" { # Renamed
					CopyFileToDestination -fileArg $item[2] -destinationArg "$destination\Added"
					CopyFileToDestination -fileArg $item[2] -destinationArg "$destination\Changed"
					DeleteFileFromDestination -deleteFileArg $item[1] -deleteDestinationArg "$destination\Deleted"
				}
				"A" { # Added
					CopyFileToDestination -fileArg $item[1] -destinationArg "$destination\Added"
					CopyFileToDestination -fileArg $item[1] -destinationArg "$destination\Changed"
				}
				"M" { # Modified
					CopyFileToDestination -fileArg $item[1] -destinationArg "$destination\Modified"
					CopyFileToDestination -fileArg $item[1] -destinationArg "$destination\Changed"
				}
				Default { # Unsupported
					CopyFileToDestination -fileArg $item[1] -destinationArg "$destination\Changed"
				}
			}
		}
	}
}
# For more information on the VSTS Task SDK:
# https://github.com/Microsoft/vsts-task-lib
Trace-VstsEnteringInvocation $MyInvocation
try {
	Initialize
	HandleDiff
} finally {
	Trace-VstsLeavingInvocation $MyInvocation
	if ($LastExitCode -ne 0) { 
		Write-Error "Something went wrong. Please check the logs."
    }
}
