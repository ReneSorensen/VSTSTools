[CmdletBinding()]
param()

$workingDir = $env:SYSTEM_DEFAULTWORKINGDIRECTORY 
$currentBranch = $env:BUILD_SOURCEBRANCHNAME 
$tag = Get-VstsInput -Name tag -Require
$shouldForceInput = Get-VstsInput -Name forceTagCreation 
[boolean]$shouldForce = [System.Convert]::ToBoolean($shouldForceInput)

if (!($env:SYSTEM_ACCESSTOKEN ))
{
    throw ("OAuth token not found. Make sure to have 'Allow Scripts to Access OAuth Token' enabled in the build definition.
			Also, give 'Project Collection Build Service' 'Contribute' and 'Create Tag' permissions - Cog -> Version Control -> {Select Repository/ies}")
}

# For more information on the VSTS Task SDK:
# https://github.com/Microsoft/vsts-task-lib
Trace-VstsEnteringInvocation $MyInvocation
try {
	Write-Verbose "Setting working directory to '$workingDir'."
    	Set-Location $workingDir
	
	write-verbose "Checkout current branch."
	write-host "##[command]"git checkout $currentBranch
	git checkout $currentBranch
	
	IF($shouldForce)	
	{	
		write-verbose "Delete remote tag"
		git push origin :refs/tags/$tag
	}
	
	Write-Verbose "Tagging '$currentBranch' with '$tag'."
    	write-host "##[command]"git tag (&{If($shouldForce) {"-f"} Else {""}}) $tag
	$errorMsg = git tag (&{If($shouldForce) {"-f"} Else {""}}) $tag 2>&1
	
	Write-Verbose "Push tag to origin"
	write-host "##[command]"git push origin $tag
	git push origin $tag
	
	if( $LastExitCode -ne 0 ){ 
	if($errorMsg){
	write-error $errorMsg
	}
	else
	{
	write-error "Something went wrong. Please check the logs."
	}
	}
} finally {
    Trace-VstsLeavingInvocation $MyInvocation
}
