[CmdletBinding()]
param()

# Find the hashId for the commit, using tag or id
function GetGitHashId([String] $rev_arg) {
    try {
        if(($rev_arg -eq $Null) -or ($rev_arg -eq '')) {
            Write-Verbose "rev_arg has no value"
            return $Null
        }
        $a = git rev-parse $rev_arg;
        if (-not $? -Or $a -eq $Null) {
            Write-Verbose "Unknown revision or path not in the working tree"
            return $Null
        }
        Write-Verbose "HashId for $($rev_arg) is " $a
        return $a
    } catch {
        throw ("Error: Something went wonky")
    }
}

# Copy file to destination
function CopyFileToDestination([String] $file_arg, [String] $destination_arg) {
	Write-Verbose "File: " $file_arg " Destination: "$destination_arg
	if($shouldFlatten)
	{
		New-Item -ItemType Directory -Path "$destination_arg" -Force | out-null
		Copy-Item $file_arg -Destination "$destination_arg"
	}
	else
	{
		$destinationPath = join-path $destination_arg $file_arg;
		Write-Verbose $destinationPath
		New-Item -ItemType Directory -Path "$destinationPath" -Force | out-null
		Copy-Item $file_arg -Destination "$destinationPath" -recurse -container;
	}
}

$workingDir = Get-VstsInput -Name workingdir -Require
$currentCommitInput = Get-VstsInput -Name currentcommit
$destination = Get-VstsInput -Name destination -Require
$gitTag = Get-VstsInput -Name gittag -Require
$shouldFlattenInput = Get-VstsInput -Name flatten 
[boolean]$shouldFlatten = [System.Convert]::ToBoolean($shouldFlattenInput)

if (!(Get-VstsTaskVariable -Name "System.AccessToken")) {
    throw ("OAuth token not found. Make sure to have 'Allow Scripts to Access OAuth Token' enabled in the build definition.
			Also, give 'Project Collection Build Service' 'Contribute' and 'Create Tag' permissions - Cog -> Version Control -> {Select Repository/ies}")
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
	Write-Verbose "Setting working directory to '$workingDir'."
	Set-Location $workingDir
	Write-Verbose "Current commit is $currentCommit"
	
	git config core.quotepath off
	[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
	
	# Get the commit SHA-1 hash ID from $currentCommit
	Set-Variable -name new_commit_hash -Value (GetGitHashId -rev_arg "$($currentCommit)")
	write-Verbose "New commit head hashid: " $new_commit_hash

	# Get the commit SHA-1 hash ID from tag
	Set-Variable -name old_commit_hash -Value (GetGitHashId -rev_arg "$($gitTag)")
	# If commit not have been found, get the first commit form repo
	if(($old_commit_hash -eq $Null) -or ($old_commit_hash -eq '')) {
		$old_commit_hash = git rev-list --max-parents=0 $currentCommit
	}
	Write-Verbose "Old commit TAG hashid: " $old_commit_hash
	
	# Diff between the two commits
	Write-Host "##[command]"git diff --name-status "$old_commit_hash $new_commit_hash"
	git diff --name-status $old_commit_hash $new_commit_hash | foreach{
		$item = @();
		$item = $_.Split([char]0x0009);
		Write-Verbose $item
		if($item.length -gt 1){
			if($item[0].Contains("D")){
				CopyFileToDestination -file_arg $item[1] -destination_arg "$destination\Deleted"
			} elseif($item[0].Contains("R")){
				CopyFileToDestination -file_arg $item[2] -destination_arg "$destination\Changes"
				CopyFileToDestination -file_arg $item[1] -destination_arg "$destination\Deleted"
			} else {
				CopyFileToDestination -file_arg $item[1] -destination_arg "$destination\Changes"
			}
		}
	}
	
} finally {
	Trace-VstsLeavingInvocation $MyInvocation
	if ($LastExitCode -ne 0) { 
		Write-Error "Something went wrong. Please check the logs."
    }
}
