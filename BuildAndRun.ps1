Param(
    [ValidateSet('DebugGame','Development','Shipping')]
    [string]$Configuration = 'Development',

    [ValidateSet('Win64')]
    [string]$Platform = 'Win64',

    [string]$UEVersion
)

$ErrorActionPreference = 'Stop'

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

try {
    # プロジェクトルートと .uproject 検出
    $projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
    $uprojectFiles = Get-ChildItem -Path $projectRoot -Filter *.uproject -File -ErrorAction Stop

    if ($uprojectFiles.Count -eq 0) {
        throw ".uproject が見つかりませんでした: $projectRoot"
    }

    if ($uprojectFiles.Count -gt 1) {
        # ディレクトリ名と一致する .uproject を優先
        $dirName = Split-Path -Leaf $projectRoot
        $preferred = $uprojectFiles | Where-Object { $_.BaseName -ieq $dirName } | Select-Object -First 1
        if ($null -eq $preferred) {
            throw "複数の .uproject が見つかりました。対象を特定できませんでした: " + ($uprojectFiles | ForEach-Object { $_.FullName } | Out-String)
        }
        $uproject = $preferred
    } else {
        $uproject = $uprojectFiles[0]
    }

    $projectName = $uproject.BaseName
    $uprojectPath = $uproject.FullName

	# .uproject の EngineAssociation から UE バージョンを取得（フォールバック無し）
	$uprojectJson = Get-Content -LiteralPath $uprojectPath -Raw | ConvertFrom-Json
	$UEVersion = $uprojectJson.EngineAssociation

    # エンジンルート（別スクリプトで解決、見つからなければエラー）
    $resolveScript = Join-Path $PSScriptRoot 'Get-UEInstallPath.ps1'
    if (-not (Test-Path -LiteralPath $resolveScript)) {
        throw "Get-UEInstallPath.ps1 が見つかりません。エンジンパスを解決できません。"
    }
    $resolvedEngineRoot = & $resolveScript -Version $UEVersion
    if (-not $resolvedEngineRoot) {
        throw ("マニフェストから UE_{0} のインストール先が見つかりませんでした。" -f $UEVersion)
    }
    if (-not (Test-Path $resolvedEngineRoot)) {
        throw ("Unreal Engine {0} のディレクトリが存在しません: {1}" -f $UEVersion, $resolvedEngineRoot)
    }

    $buildBat = Join-Path $resolvedEngineRoot 'Engine\\Build\\BatchFiles\\Build.bat'
    $editorExe = Join-Path $resolvedEngineRoot 'Engine\\Binaries\\Win64\\UnrealEditor.exe'

    if (-not (Test-Path $buildBat)) { throw "Build.bat が見つかりません: $buildBat" }
    if (-not (Test-Path $editorExe)) { throw "UnrealEditor.exe が見つかりません: $editorExe" }

    # ビルド（Editor ターゲット）
    $editorTarget = "${projectName}Editor"
    $buildArgs = @(
        $editorTarget,
        $Platform,
        $Configuration,
        "-Project=`"$uprojectPath`"",
        '-WaitMutex',
        '-FromMsBuild',
        '-NoHotReload'
    ) -join ' '

    Write-Info "ビルド開始: $editorTarget $Platform $Configuration"
    Write-Info "Engine: $resolvedEngineRoot"
    Write-Info "Project: $uprojectPath"

    $buildProc = Start-Process -FilePath $buildBat -ArgumentList $buildArgs -NoNewWindow -PassThru -Wait
    $exitCode = $buildProc.ExitCode

    if ($exitCode -ne 0) {
        Write-Err "ビルドに失敗しました。ExitCode=$exitCode"
        exit $exitCode
    }

    Write-Info 'ビルド成功。Unreal Editor を起動します。'
    $editorArgs = '"' + $uprojectPath + '"'
    Start-Process -FilePath $editorExe -ArgumentList $editorArgs | Out-Null
}
catch {
    Write-Err $_.Exception.Message
    exit 1
}
