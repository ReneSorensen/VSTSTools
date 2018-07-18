$runFromBuildServer = ($env:TF_Build -eq "True")

Write-Host "Configure node / cross platform version"
Write-Host "npm install"
npm install

Write-Host "npm run build"
npm run build

if ($runFromBuildServer) {
    Write-Host "Copying node_modules to the task folder"
    Move-Item .\node_modules .\GitTag\
}
else {
    tfx extension create --manifest-globs vss-extension.json --rev-version
}