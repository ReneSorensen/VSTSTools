[CmdletBinding()]
param()

$workingDir = $env:SYSTEM_DEFAULTWORKINGDIRECTORY 
$tag = Get-VstsInput -Name tag -Require
$shouldForceInput = Get-VstsInput -Name forceTagCreation 
[boolean]$shouldForce = [System.Convert]::ToBoolean($shouldForceInput)

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
    Write-Host "##[command]"git tag (& {If ($shouldForce) {"-f"} Else {""}}) $tag
    $errorMsg = git tag (& {If ($shouldForce) {"-f"} Else {""}}) $tag 2>&1
	
    Write-Verbose "Push tag to origin"
    Write-Host "##[command]"git push origin $tag
    git push origin $tag
	
    if ($LastExitCode -ne 0) { 
        if ($errorMsg) {
            Write-Error $errorMsg
        }
        else {
            Write-Error "Something went wrong. Please check the logs."
        }
    }
}
finally {
    Trace-VstsLeavingInvocation $MyInvocation
}
