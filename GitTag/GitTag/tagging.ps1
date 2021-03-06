[CmdletBinding()]
param()
function showRedirectedOutput
{
    param ($output)

    $output | ForEach-Object -Process `
    {
            Write-Host "$_"
    }
}

$currentCommitInput = Get-VstsInput -Name currentcommit
$workingDir = Get-VstsInput -Name workingdir -Require
$tag = Get-VstsInput -Name tag -Require
$shouldForceInput = Get-VstsInput -Name forceTagCreation 
$tagger = Get-VstsInput -Name tagUser
$taggerEmail = Get-VstsInput -Name tagEmail
$useLightweightTagsInput = Get-VstsInput -Name useLightweightTags
$tagMessage = Get-VstsInput -Name tagMessage
[boolean]$shouldForce = [System.Convert]::ToBoolean($shouldForceInput)
[boolean]$useLightweightTags = [System.Convert]::ToBoolean($useLightweightTagsInput)

# currentCommitInput is empty use HEAD
if(($Null -eq $currentCommitInput) -or ($currentCommitInput -eq '')) {
    $Script:currentCommit = "HEAD"
} else {
    $Script:currentCommit = $currentCommitInput
}
Write-Host "Current commit is $currentCommit"

if (!(Get-VstsTaskVariable -Name "System.AccessToken")) {
    throw ("OAuth token not found. Make sure to have 'Allow Scripts to Access OAuth Token' enabled in the build or release definition.
			Also, give 'Project Collection Build Service' 'Contribute' and 'Create Tag' permissions - Cog -> Version Control -> {Select Repository/ies}")
}

# For more information on the VSTS Task SDK:
# https://github.com/Microsoft/vsts-task-lib
Trace-VstsEnteringInvocation $MyInvocation
try {
    Write-Verbose "Setting working directory to '$workingDir'."
    Set-Location -LiteralPath $workingDir
    
	git config user.email "$taggerEmail"
	git config user.name "$tagger"
    
    if ($shouldForce) {	
        Write-Verbose "Delete remote tag"
        git push origin :refs/tags/$tag
    }
	
    # We tag on the currently-checked out branch/commit.
    Write-Verbose "Tagging with '$tag'."
    if(!$tagMessage) {
        $tagMessage = $tag
    }
	Write-Host "##[command]"git tag (& {If ($shouldForce) {"-f"} Else {""}}) (& {If ($useLightweightTags) {""} Else {"-a"}}) $tag (& {If (-Not $useLightweightTags){"-m $tagMessage"}}) $currentCommit
    $tagOutput = git tag (& {If ($shouldForce) {"-f"} Else {""}}) (& {If ($useLightweightTags) {""} Else {"-a"}}) $tag (& {If (-Not $useLightweightTags){"-m $tagMessage"}}) $currentCommit 2>&1 
	
    try {
        $backupErrorActionPreference = $script:ErrorActionPreference
        $script:ErrorActionPreference = 'Continue'
        
		Write-Verbose "Push tag to origin"
		Write-Host "##[command]"git push origin $tag
		$pushOutput =  git push origin $tag 2>&1

		showRedirectedOutput $tagOutput
		showRedirectedOutput $pushOutput
		
		if ($LastExitCode -ne 0) { 
			Write-Error "Something went wrong. Please check the logs."
		}
	}
	finally 
	{
		$script:ErrorActionPreference = $backupErrorActionPreference	
	}

}
finally {
    Trace-VstsLeavingInvocation $MyInvocation
}
