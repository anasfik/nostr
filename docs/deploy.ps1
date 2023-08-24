$currentPath = (Get-Location).path
$onlyCurrentFolderName = $currentPath.Split("\")[-1]

function Deploy() {
    cmd /C 'set "GIT_USER=anasfik" && npm run deploy'
}

if ($onlyCurrentFolderName -ne "docs") {
if($onlyCurrentFolderName -eq "nostr") {

Set-Location docs
Deploy

}  else {
echo "You are not in the right folder"
}
} else {
 Deploy
 }

