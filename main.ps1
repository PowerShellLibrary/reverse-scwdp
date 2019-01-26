Clear-Host

if (-not(Test-Path "$PSScriptRoot\configuration.json")) {
    Write-Host "Cannot find configuration file '.\configuration.json' because it does not exist." -ForegroundColor Red
    return
}
$config = Get-Content .\configuration.json | ConvertFrom-Json
Write-Host "Preparing directory" -ForegroundColor Green
if (Test-Path -Path .\temp) {
    Write-Host "Removing temporary directories" -ForegroundColor Green
    Remove-Item -Path .\temp -Force -Recurse
}

Write-Host "Looking for zip with packages" -ForegroundColor Green
$archiveFile = Get-ChildItem . -Filter "Sitecore*.zip" | Select-Object -First 1
if ($archiveFile) {
    Write-Host "Archive found" -ForegroundColor Green
    Write-Host "Extracting" -ForegroundColor Green
    Expand-Archive '.\Sitecore 9.1.0 rev. 001564 (WDP XP0 packages).zip' -DestinationPath "temp"

    Write-Host "Looking for scwdp package" -ForegroundColor Green
    $wdpPackage = Get-ChildItem -Path ".\temp" -Filter "*single.scwdp.zip" | Select-Object -First 1
    if ($wdpPackage) {
        Write-Host "scwdp found" -ForegroundColor Green
        $folderName = $wdpPackage.Name.Replace(" (OnPrem)_single.scwdp", "").Replace(".zip", "")

        Write-Host "Extracting 'dacpac' files" -ForegroundColor Green
        .\7za920\7za.exe e "$($wdpPackage.FullName)" -otemp\dacpac *.dacpac

        Write-Host "scwdop archive cleanup" -ForegroundColor Green
        .\7za920\7za.exe d "$($wdpPackage.FullName)" *.*

        Write-Host "Converting databases" -ForegroundColor Green
        .\converet-db.ps1 $config.sqlUser $config.sqlPassword $config.serverName


        mkdir "temp\Data\packages"
        Write-Host "Packaging databases" -ForegroundColor Green

        Set-Location .\7za920
        $path = "$($wdpPackage.FullName)".Replace($PSScriptRoot, "..")

        Write-Host "Adding databases to archive" -ForegroundColor Green
        7za a $path ..\temp\dacpac\mdf
        7za rn $path "mdf" "$folderName\Databases"

        Write-Host "Adding Data folder to archive" -ForegroundColor Green
        7za a $path ..\temp\Data
        7za rn $path "Data" "$folderName\Data"

        7za rn $path "Content" "$folderName"
        Set-Location ..

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
    }
}

Write-Host "Removing temp folder" -ForegroundColor Green
$temp = Get-Item -Path .\temp
$temp | Remove-Item -Force -Recurse