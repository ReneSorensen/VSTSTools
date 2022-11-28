This extension includes the following tasks

* Git Tag
	
## Git Tag
Tags the current commit with a specified tag and pushes it to origin.

### Yaml example
```yaml
steps:
  - checkout: self
    persistCredentials: True

  - task: ATP.ATP-GitTag.GitTag.GitTag@6
    displayName: 'Set Git Tag Latest Feed'
    condition: and(succeeded(), ne(variables['${{parameters.deploy_reason}}'], 'Manual'))
    inputs:
      workingdir: '$(Build.SourcesDirectory)'
      tag: ${{parameters.LatestFeed}}
      useLightweightTags: true
      forceTagCreation: true
```

## New features
Majer release change, removed typescript from the solution, because of vulnerability.
This solution only contains powershell now.
## Features
New field commit ID, which allows you to select a specific, use source version from pipeline or something else. If the field is not filled in, HEAD will be used. 
This will fix that tag is added to the current commit, not always the newest in the branch.

## Features
Default behaviour is to use annoted tags (can be opted out).
Can force tag.
Can add tag message.
Any directory can be specified as git source folder.

### Prerequisites

* Windows / Hosted agent.
* Repository must be VSTS Git.
* Project Collection Build Service must have **Contribute** & **Create Tag** set to **Allow** or **Inherit Allow** for that particular repository
* Allow scripts to access Oauth must be **Enabled**  
 Select this check box in classic build pipelines if you want to enable your script to use the build pipeline OAuth token. This check box is located under the "additional settings" section after selecting the agent job in the pipeline
 In yaml - add a checkout section with persistCredentials set to true.

## Credits
<div>Icons made by <a href="http://www.flaticon.com/authors/madebyoliver" title="Madebyoliver">Madebyoliver</a> from <a href="http://www.flaticon.com" title="Flaticon">www.flaticon.com</a> is licensed by <a href="http://creativecommons.org/licenses/by/3.0/" title="Creative Commons BY 3.0" target="_blank">CC 3.0 BY</a></div>

## EULA
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS  
OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF  
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,  
DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT  
OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE  
OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.