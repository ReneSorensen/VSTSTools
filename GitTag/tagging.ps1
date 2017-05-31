[CmdletBinding()]
param()

$workingDir = $env:SYSTEM_DEFAULTWORKINGDIRECTORY 
$currentBranch = $env:BUILD_SOURCEBRANCHNAME 
$tag = Get-VstsInput -Name tag -Require

if (!($authToken))
{
    throw ("OAuth token not found. Make sure to have 'Allow Scripts to Access OAuth Token' enabled in the build definition.
			Also, give 'Project Collection Build Service' 'Contribute' and 'Create Tag' permissions - Cog -> Version Control -> {Select Repository/ies}
	")
}

# For more information on the VSTS Task SDK:
# https://github.com/Microsoft/vsts-task-lib
Trace-VstsEnteringInvocation $MyInvocation
try {
	Write-Verbose "Setting working directory to '$workingDir'."
    Set-Location $workingDir
	git checkout $currentBranch
	Write-Verbose "Tagging '$currentBranch' with '$tag'"
    git tag $tag $currentBranch
	
	git push origin $tag
	
} finally {
    Trace-VstsLeavingInvocation $MyInvocation
}
