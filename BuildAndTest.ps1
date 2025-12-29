Param(
    [Parameter(Mandatory = $true)]
    [string]$TestFilter,

    [ValidateSet('DebugGame', 'Development', 'Shipping')]
    [string]$Configuration = 'Development',

    [ValidateSet('Win64')]
    [string]$Platform = 'Win64'
)

$ErrorActionPreference = 'Stop'

$commonScript = Join-Path $PSScriptRoot 'BuildCommon.ps1'
if (-not (Test-Path -LiteralPath $commonScript)) {
    Write-Host "[ERROR] BuildCommon.ps1 not found: $commonScript" -ForegroundColor Red
    exit 1
}
. $commonScript

function Get-SafeFolderName {
    param([string]$Name)
    $invalidChars = [System.IO.Path]::GetInvalidFileNameChars()
    $safeName = $Name
    foreach ($char in $invalidChars) {
        $safeName = $safeName.Replace($char, '_')
    }
    if ([string]::IsNullOrWhiteSpace($safeName)) {
        return 'Tests'
    }
    return $safeName
}

try {
    if ([string]::IsNullOrWhiteSpace($TestFilter)) {
        throw 'Test filter is required. Example: -TestFilter MySpec'
    }

    $engineResolverScript = Join-Path $PSScriptRoot 'Get-UEInstallPath.ps1'
    $engineRootResolver = New-EngineRootResolverFromScript -ScriptPath $engineResolverScript

    $buildResult = Invoke-ProjectBuild `
        -ScriptRoot $PSScriptRoot `
        -Platform $Platform `
        -Configuration $Configuration `
        -EngineRootResolver $engineRootResolver

    if ($buildResult.ExitCode -ne 0) {
        Write-Err "Build failed. ExitCode=$($buildResult.ExitCode)"
        exit $buildResult.ExitCode
    }

    $editorCmd = Join-Path $buildResult.EngineRoot 'Engine\\Binaries\\Win64\\UnrealEditor-Cmd.exe'
    Assert-PathExists -Path $editorCmd -Description 'UnrealEditor-Cmd.exe'

    $projectRoot = Split-Path -Parent $buildResult.UProjectPath
    $reportRoot = Join-Path $projectRoot 'Saved\\AutomationReports'
    $reportFolderName = Get-SafeFolderName -Name $TestFilter
    $reportExportPath = Join-Path $reportRoot $reportFolderName
    $null = New-Item -ItemType Directory -Force -Path $reportExportPath

    $execCmds = "Automation RunTests $TestFilter; Quit"
    $cmdArgs = @(
        "`"$($buildResult.UProjectPath)`"",
        "-ExecCmds=`"$execCmds`"",
        "-ReportExportPath=`"$reportExportPath`"",
        '-unattended',
        '-nop4',
        '-nosplash',
        '-nullrhi'
    ) -join ' '

    Write-Info "Tests started: $TestFilter"
    Write-Info "Engine: $($buildResult.EngineRoot)"
    Write-Info "Project: $($buildResult.UProjectPath)"
    Write-Info "Report: $reportExportPath"

    $editorCmdDir = Split-Path -Parent $editorCmd
    $proc = Start-Process -FilePath $editorCmd -ArgumentList $cmdArgs -WorkingDirectory $editorCmdDir -NoNewWindow -PassThru -Wait
    $exitCode = $proc.ExitCode

    if ($exitCode -ne 0) {
        Write-Err "Tests failed. ExitCode=$exitCode"
        exit $exitCode
    }

    Write-Info 'Tests completed.'
}
catch {
    Write-Err $_.Exception.Message
    exit 1
}
