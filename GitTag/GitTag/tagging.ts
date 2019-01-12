import tl = require('vsts-task-lib/task');
import git = require('git-exec');
import fs = require('fs');

function repoExecAsync(repo, gitCommand, showGitCmd: boolean = true) : Promise<string>{
    if (showGitCmd)
        console.log(`##[command]git ${gitCommand}`);

    return new Promise(function(resolve, reject) {
        repo.exec(gitCommand, null, function(err, stdout) {
            if(err !== null) 
                return reject(err);
            resolve(stdout);
        });
    });
}

function sanitizeConfigOutput(output: string) {
    return output.replace("\n", "");
}

function logIfNotEmpty(logOutput: string) {
    if (logOutput)
        console.log(logOutput);
}

async function run() {
	try {
        
        if (!tl.getVariable("SYSTEM_ACCESSTOKEN")) {
            throw ("OAuth token not found. Make sure to have 'Allow Scripts to Access OAuth Token' enabled in the build or release definition.\n" +
                    "Also, give 'Project Collection Build Service' 'Contribute' and 'Create Tag' permissions - Cog -> Version Control -> {Select Repository/ies}");
        }

        var workingDir = tl.getInput('workingdir', true);
        var tag = tl.getInput('tag', true);
        var shouldForce = tl.getBoolInput('forceTagCreation');
        var tagger = tl.getInput('tagUser');
        var taggerEmail = tl.getInput('tagEmail');
        var useLightweightTags = tl.getBoolInput('useLightweightTags');
        var tagMessage = tl.getInput('tagMessage');
        tagMessage = tagMessage || tag;

        if (!fs.existsSync(workingDir)) {
            throw `Could not find directory ${workingDir}`;
        }
        console.log(`Setting working directory to '${workingDir}'.`);
        var repo = new git(workingDir);
        try {
            await repoExecAsync(repo, "status", false);
        }
        catch {
            throw `'${workingDir}' does not appear to be a git repository`;
        }

        var gitConfigAll = await repoExecAsync(repo, "config --list", false);
        tl.debug(`git config --all\n${gitConfigAll}`);

        // Save original git configs for user and email.
        var originalEmail: string = null;
        var originalName: string = null;

        // If these aren't set then windows throws a non-zero exit code
        try {
            originalEmail = sanitizeConfigOutput(await repoExecAsync(repo, "config --local --get user.email", false));
        }
        catch {}
        try {
            originalName = sanitizeConfigOutput(await repoExecAsync(repo, "config --local --get user.name", false));
        }
        catch {}

        if (taggerEmail != null) {
            await repoExecAsync(repo, `config user.email "${taggerEmail}"`);
        }
        if (tagger != null) {
            await repoExecAsync(repo, `config user.name "${tagger}"`);
        }
        var forceCmd = shouldForce ? "-f" : "";
        var tagCmd;
        if(useLightweightTags) {  
            tagCmd = `tag ${forceCmd} "${tag}"`;
         } else {
            tagCmd = `tag ${forceCmd} -a "${tag}" -m "${tagMessage}"`;  
         }

        if (shouldForce) {
            console.log("Delete remote tag")

            var output = await repoExecAsync(repo, `push origin :refs/tags/${tag}`);
            logIfNotEmpty(output);
        }

        var tagResult = await repoExecAsync(repo, tagCmd);
        logIfNotEmpty(tagResult);

        console.log("Push tag to origin");
        var pushOutput = await repoExecAsync(repo, `push origin ${tag}`);
        // This always seems to be empty. I assume it's because the git messages are output to stdErr rather than stdOut
        logIfNotEmpty(pushOutput)
    }
    catch(err) {
        var msg = err.message || err;
        tl.error(msg);
        tl.setResult(tl.TaskResult.Failed, "Git Repo Tagger Failed.");
    }
    finally {
        // Cleanup:
        //  * Set the git config user.email and user.name back to original values
        if (originalEmail != null)
            await repoExecAsync(repo, `config user.email "${originalEmail}"`, false);
        if (originalName != null) 
            await repoExecAsync(repo, `config user.name "${originalName}"`, false);
    }
}

run();