function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Cyan
}

function Write-Warn {
    param([string]$Message)
    Write-Host "[WARN] $Message" -ForegroundColor Yellow
}

function Write-Err {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

function Get-ProjectRoot {
    param([string]$ScriptRoot)
    return (Resolve-Path (Join-Path $ScriptRoot '..')).Path
}

function Get-ProjectInfo {
    param([string]$ProjectRoot)

    $uprojectFiles = Get-ChildItem -Path $ProjectRoot -Filter *.uproject -File -ErrorAction Stop

    if ($uprojectFiles.Count -eq 0) {
        throw "No .uproject found: $ProjectRoot"
    }

    if ($uprojectFiles.Count -gt 1) {
        $dirName = Split-Path -Leaf $ProjectRoot
        $preferred = $uprojectFiles | Where-Object { $_.BaseName -ieq $dirName } | Select-Object -First 1
        if ($null -eq $preferred) {
            $paths = $uprojectFiles | ForEach-Object { $_.FullName } | Out-String
            throw "Multiple .uproject files found. Unable to determine target: $paths"
        }
        $uproject = $preferred
    }
    else {
        $uproject = $uprojectFiles[0]
    }

    return [pscustomobject]@{
        ProjectRoot  = $ProjectRoot
        ProjectName  = $uproject.BaseName
        UProjectPath = $uproject.FullName
    }
}

function Get-UEVersionFromProject {
    param([string]$UProjectPath)
    $uprojectJson = Get-Content -LiteralPath $UProjectPath -Raw | ConvertFrom-Json
    return $uprojectJson.EngineAssociation
}

function New-EngineRootResolverFromScript {
    param([string]$ScriptPath)

    if (-not (Test-Path -LiteralPath $ScriptPath)) {
        throw "Engine resolver script not found: $ScriptPath"
    }

    $resolverScriptPath = $ScriptPath
    $resolver = { param([string]$Version) & $resolverScriptPath -Version $Version }
    return $resolver.GetNewClosure()
}

function Get-EngineRoot {
    param(
        [string]$UEVersion,
        [ScriptBlock]$EngineRootResolver
    )

    if ($null -eq $EngineRootResolver) {
        throw "Engine root resolver is not provided."
    }

    $resolvedEngineRoot = & $EngineRootResolver -Version $UEVersion
    if (-not $resolvedEngineRoot) {
        throw ("Engine root not resolved for UE_{0}." -f $UEVersion)
    }
    if (-not (Test-Path -LiteralPath $resolvedEngineRoot)) {
        throw ("Unreal Engine {0} directory not found: {1}" -f $UEVersion, $resolvedEngineRoot)
    }

    return $resolvedEngineRoot
}

function Assert-PathExists {
    param(
        [string]$Path,
        [string]$Description
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw ("{0} not found: {1}" -f $Description, $Path)
    }
}

function Get-EditorBuildArgs {
    param(
        [string]$ProjectName,
        [string]$Platform,
        [string]$Configuration,
        [string]$UProjectPath
    )

    return @(
        "${ProjectName}Editor",
        $Platform,
        $Configuration,
        "-Project=`"$UProjectPath`"",
        '-WaitMutex',
        '-FromMsBuild',
        '-NoHotReload'
    ) -join ' '
}

function Invoke-EditorBuild {
    param(
        [string]$BuildBat,
        [string]$BuildArgs
    )

    $buildProc = Start-Process -FilePath $BuildBat -ArgumentList $BuildArgs -NoNewWindow -PassThru -Wait
    return $buildProc.ExitCode
}

function Invoke-ProjectBuild {
    param(
        [string]$ScriptRoot,
        [string]$Platform,
        [string]$Configuration,
        [ScriptBlock]$EngineRootResolver
    )

    $projectRoot = Get-ProjectRoot -ScriptRoot $ScriptRoot
    $projectInfo = Get-ProjectInfo -ProjectRoot $projectRoot

    $UEVersion = Get-UEVersionFromProject -UProjectPath $projectInfo.UProjectPath
    $engineRoot = Get-EngineRoot -UEVersion $UEVersion -EngineRootResolver $EngineRootResolver

    $buildBat = Join-Path $engineRoot 'Engine\\Build\\BatchFiles\\Build.bat'
    Assert-PathExists -Path $buildBat -Description 'Build.bat'

    $buildArgs = Get-EditorBuildArgs `
        -ProjectName $projectInfo.ProjectName `
        -Platform $Platform `
        -Configuration $Configuration `
        -UProjectPath $projectInfo.UProjectPath

    $editorTarget = "{0}Editor" -f $projectInfo.ProjectName
    Write-Info "Build started: $editorTarget $Platform $Configuration"
    Write-Info "Engine: $engineRoot"
    Write-Info "Project: $($projectInfo.UProjectPath)"

    $exitCode = Invoke-EditorBuild -BuildBat $buildBat -BuildArgs $buildArgs

    return [pscustomobject]@{
        ProjectName  = $projectInfo.ProjectName
        UProjectPath = $projectInfo.UProjectPath
        EngineRoot   = $engineRoot
        ExitCode     = $exitCode
    }
}
