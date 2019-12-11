param(
    [parameter(Mandatory = $true, Position = 0)]
    [string]$sqlUser,
    [parameter(Mandatory = $true, Position = 1)]
    [string]$sqlPassword,
    [parameter(Mandatory = $true, Position = 2)]
    [string]$serverName,
    [parameter(Mandatory = $true, Position = 3)]
    $dacPacPath,
    [parameter(Mandatory = $true, Position = 4)]
    [string]$dbLocation,
    [parameter(Mandatory = $false, Position = 5)]
    [string]$sqlInstallationBinFolder = "C:\Program Files (x86)\Microsoft SQL Server\140\DAC\bin",
    [parameter(Mandatory = $false, Position = 6)]
    [string]$tempDbNamePrefix = "PoweShellTransformation."
)

function Test-SQLConnection {
    [OutputType([bool])]
    Param
    (
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
        $ConnectionString
    )
    try {
        $sqlConnection = New-Object System.Data.SqlClient.SqlConnection $ConnectionString;
        $sqlConnection.Open();
        $sqlConnection.Close();

        return $true;
    }
    catch {
        return $false;
    }
}

if (-not (Test-Path $sqlInstallationBinFolder)) {
    Write-Host "Incorrect sqlInstallationBinFolder: $sqlInstallationBinFolder" -ForegroundColor Red
    exit
}

if (-not (Test-Path "$sqlInstallationBinFolder\SqlPackage.exe")) {
    Write-Host "Could not find SqlPackage.exe: $sqlInstallationBinFolder\SqlPackage.exe" -ForegroundColor Red
    exit
}

if (-not (Test-SQLConnection "Data Source=$serverName;database=master;User ID=$sqlUser;Password=$sqlPassword;")) {
    Write-Host "Could not connect to a database. Check credentials" -ForegroundColor Red
    exit
}


if (-not(Test-Path "$dbLocation")) {
    New-Item -ItemType directory -Path "$dbLocation"
}

if (-not(Test-Path $dacPacPath)) {
    Write-Error "Cannot find file"
}

$dacPac = Get-Item -Path $dacPacPath

$name = $tempDbNamePrefix + $dacPac.Name.Replace(".dacpac", "")
$srcPath = $dacPac.FullName

# publish db from script
Write-Host "Processing $($_.Name)" -ForegroundColor Green
& "$sqlInstallationBinFolder\SqlPackage.exe" /action:Publish /SourceFile:$srcPath /TargetServerName:$serverName /TargetDatabaseName:$name /TargetUser:$sqlUser /TargetPassword:$sqlPassword

# get database files paths
$query = "select name, physical_name from sys.master_files where name like '$name%' and physical_name like '%$name%'"
$paths = Invoke-Sqlcmd -ServerInstance $serverName -Database "master" -Query $query -Username $sqlUser -Password $sqlPassword | % { $_.physical_name }

$paths | % { Write-Host $_ -ForegroundColor Yellow }
# detach database
$query = "sp_detach_db '$name', 'true';"
Invoke-Sqlcmd -ServerInstance $serverName -Database "master" -Query $query -Username $sqlUser -Password $sqlPassword

# move mdf and ldf files
$paths | % { Move-Item -Path $_ -Destination $dbLocation -Force }

# set file names
Get-ChildItem -Path "$dbLocation" | % {
    $newName = $_.Name.Replace("_Primary", "").Replace($tempDbNamePrefix, [string]::Empty)
    Rename-Item -Path $_.FullName -NewName $newName
}