This extension includes the following tasks

* Git Copy Diff between 2 commits
	
## Git Copy Changed Files
Finds git-diff between two commits and copies files that have been added/modified/renamed/moved to a specified folder with extension \Changed. It also create one file in the folder \Deleted which files should be removed from reposity.
\Changed and \Deleted folder will always be created even if nothing is stored in the folders

## Features
The diff is found between the two commits "Current commit" and "Tag". 
"Current commit" use commit-id and if not set, HEAD will be used. 
Tag can be tag for given commit or can be hashid. If commit is not found, use branch as root if value is insert, if not the first commit will be used.
You can specify which files to copy by change type. 
Folder Changed and Deleted will be created even if there are no items to be found.
Flatten directory structure (all files to same directory).


### Prerequisites

* Repository must be Git.
* Allow scripts to access Oauth must be **Enabled**

## Credits
<div>Icons made by <a href="http://www.flaticon.com/authors/madebyoliver" title="Madebyoliver">Madebyoliver</a> from <a href="http://www.flaticon.com" title="Flaticon">www.flaticon.com</a> is licensed by <a href="http://creativecommons.org/licenses/by/3.0/" title="Creative Commons BY 3.0" target="_blank">CC 3.0 BY</a></div>
