Clear-Host
$toolsPath = "tools"

function Get-NugetExe {
    param ($toolsPath)
    $nugetDir = "$toolsPath\nuget"
    if (-not(Test-Path $nugetDir)) {
        New-Item -ItemType Directory -Path $nugetDir | Out-Null
    }
    $targetNugetExe = "$nugetDir\nuget.exe"
    if (-not(Test-Path $targetNugetExe)) {
        Write-Host "Downloading nuget.exe" -ForegroundColor Green
        $sourceNugetExe = "https://dist.nuget.org/win-x86-commandline/latest/nuget.exe"
        Invoke-WebRequest $sourceNugetExe -OutFile $targetNugetExe | Out-Null
    }
    $targetNugetExe
}

if (-not(Get-Alias nuget -ErrorAction SilentlyContinue)) {
    $targetNugetExe = Get-NugetExe $toolsPath
    Set-Alias nuget $targetNugetExe -Scope Script
}

$toolName = "7-Zip.CommandLine"
nuget install $toolName -OutputDirectory "$toolsPath\$toolName"
$7zip = Get-Item -Path "$toolsPath\$toolName\*\tools\7za.exe"
Set-Alias 7zip $7zip.FullName -Scope Script


if (-not(Test-Path "$PSScriptRoot\configuration.json")) {
    Write-Host "Cannot find configuration file '.\configuration.json' because it does not exist." -ForegroundColor Red
    return
}
$config = Get-Content .\configuration.json | ConvertFrom-Json
Write-Host "Preparing directory" -ForegroundColor Green
if (Test-Path -Path "temp") {
    Write-Host "Removing temporary directories" -ForegroundColor Green
    Remove-Item -Path .\temp -Force -Recurse
}
New-Item -ItemType Directory -Path "temp" | Out-Null

Write-Host "Looking for scwdp package" -ForegroundColor Green
$wdpPackage = Get-ChildItem -Path . -Filter "*single.scwdp.zip" | Select-Object -First 1
if ($wdpPackage) {
    Write-Host "scwdp found" -ForegroundColor Green
    Move-Item -Path $wdpPackage.FullName -Destination ".\temp"
    $wdpPackage = Get-Item -Path "temp\$($wdpPackage.Name)"
    if (-not($wdpPackage)) {
        Write-Error "Couldn't find archive."
        exit
    }
    $folderName = $wdpPackage.Name.Replace(" (OnPrem)_single.scwdp", "").Replace(".zip", "")
    Write-Host "Extracting 'dacpac' files" -ForegroundColor Green
    7zip e "$($wdpPackage.FullName)" -otemp\dacpac *.dacpac

    Write-Host "scwdop archive cleanup" -ForegroundColor Green
    7zip d "$($wdpPackage.FullName)" *.*

    Write-Host "Converting databases" -ForegroundColor Green
    $dbLocation = ".\temp\dacpac"
    Get-ChildItem -Path $dbLocation | ? { $_.Extension -eq ".dacpac" } | % {
        .\create-db-from-dacpac.ps1 $config.sqlUser $config.sqlPassword $config.serverName $_.FullName "$dbLocation\mdf"
    }

    mkdir "temp\Data\packages"
    Write-Host "Packaging databases" -ForegroundColor Green

    $path = $wdpPackage.FullName

    Write-Host "Adding databases to archive" -ForegroundColor Green
    7zip a $path "temp\dacpac\mdf"
    7zip rn $path "temp\dacpac\mdf" "$folderName\Databases"

    Write-Host "Adding Data folder to archive" -ForegroundColor Green
    7zip a $path "temp\Data"
    7zip rn $path "temp\Data" "$folderName\Data"

    7zip rn $path "Content" "$folderName"

    if (Test-Path "$PSScriptRoot\$($wdpPackage.Name)") {
        Write-Host "File '$PSScriptRoot\$($wdpPackage.Name)' already exists" -ForegroundColor Yellow
        $confirmation = Read-Host "Do you want to overwrite"
        if ($confirmation -eq 'y') {
            Remove-Item -Path $PSScriptRoot\$($wdpPackage.Name)
        }
        else {
            Write-Host "Script aborted"
            return
        }
    }

    Write-Host "Moving processed wdp to outp folder" -ForegroundColor Green
    Move-Item -Path $wdpPackage.FullName -Destination $PSScriptRoot
    $wdp = Get-ChildItem -Path "." -Filter "*single.scwdp.zip" | Select-Object -First 1

    Write-Host "Renaming package" -ForegroundColor Green
    Write-Host "$PSScriptRoot\$folderName.1click" -ForegroundColor Green
    $fileName = "$folderName.1click"
    if (Test-Path "$PSScriptRoot\$folderName.1click") {
        Write-Host "File with that name already exists" -ForegroundColor Green
        $postfix = (New-Guid).ToString()
        $fileName = "$folderName-$postfix.1click"
        Write-Host "New file name: '$fileName'" -ForegroundColor Green
    }
    Rename-Item -Path $wdp.FullName -NewName $fileName
}else {
    Write-Host "Couldn't find any scwdp package" -ForegroundColor Magenta
}

Write-Host "Removing temp folder" -ForegroundColor Green
$temp = Get-Item -Path .\temp
$temp | Remove-Item -Force -Recurse