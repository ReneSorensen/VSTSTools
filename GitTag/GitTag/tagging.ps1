[CmdletBinding()]
param()

$workingDir = Get-VstsInput -Name workingdir -Require
$tag = Get-VstsInput -Name tag -Require
$shouldForceInput = Get-VstsInput -Name forceTagCreation 
$useLightweightTagsInput = Get-VstsInput -Name useLightweightTags
$tagMessage = Get-VstsInput -Name tagMessage
[boolean]$shouldForce = [System.Convert]::ToBoolean($shouldForceInput)
[boolean]$useLightweightTags = [System.Convert]::ToBoolean($useLightweightTagsInput)

if (!($env:SYSTEM_ACCESSTOKEN )) {
    throw ("OAuth token not found. Make sure to have 'Allow Scripts to Access OAuth Token' enabled in the build definition.
			Also, give 'Project Collection Build Service' 'Contribute' and 'Create Tag' permissions - Cog -> Version Control -> {Select Repository/ies}")
}

# For more information on the VSTS Task SDK:
# https://github.com/Microsoft/vsts-task-lib
Trace-VstsEnteringInvocation $MyInvocation
try {
    Write-Verbose "Setting working directory to '$workingDir'."
    Set-Location $workingDir
	
    if ($shouldForce) {	
        Write-Verbose "Delete remote tag"
        git push origin :refs/tags/$tag
    }
	
    # We tag on the currently-checked out branch/commit.
    Write-Verbose "Tagging with '$tag'."
    if(!$tagMessage) {
        $tagMessage = $tag
    }
    Write-Host "##[command]"git tag (& {If ($shouldForce) {"-f"} Else {""}}) (& {If ($useLightweightTags) {""} Else {"-a"}}) $tag -m "$tagMessage"
    $tagOutput = git tag (& {If ($shouldForce) {"-f"} Else {""}}) (& {If ($useLightweightTags) {""} Else {"-a"}}) $tag -m "$tagMessage" 2>&1  
	
    Write-Verbose "Push tag to origin"
    Write-Host "##[command]"git push origin $tag
    $pushOutput =  git push origin $tag 2>&1

    if ($LastExitCode -ne 0) { 
        write-Host $tagOutput
        Write-Host $pushOutput
        Write-Error "Something went wrong. Please check the logs."
    }

    write-verbose $tagOutput
    Write-Verbose $pushOutput
}
finally {
    Trace-VstsLeavingInvocation $MyInvocation
}
