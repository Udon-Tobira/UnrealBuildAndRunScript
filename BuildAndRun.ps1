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
    # �v���W�F�N�g���[�g�� .uproject ���o
    $projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
    $uprojectFiles = Get-ChildItem -Path $projectRoot -Filter *.uproject -File -ErrorAction Stop

    if ($uprojectFiles.Count -eq 0) {
        throw ".uproject ��������܂���ł���: $projectRoot"
    }

    if ($uprojectFiles.Count -gt 1) {
        # �f�B���N�g�����ƈ�v���� .uproject ��D��
        $dirName = Split-Path -Leaf $projectRoot
        $preferred = $uprojectFiles | Where-Object { $_.BaseName -ieq $dirName } | Select-Object -First 1
        if ($null -eq $preferred) {
            throw "������ .uproject ��������܂����B�Ώۂ����ł��܂���ł���: " + ($uprojectFiles | ForEach-Object { $_.FullName } | Out-String)
        }
        $uproject = $preferred
    } else {
        $uproject = $uprojectFiles[0]
    }

    $projectName = $uproject.BaseName
    $uprojectPath = $uproject.FullName

	# .uproject �� EngineAssociation ���� UE �o�[�W�������擾�i�t�H�[���o�b�N�����j
	$uprojectJson = Get-Content -LiteralPath $uprojectPath -Raw | ConvertFrom-Json
	$UEVersion = $uprojectJson.EngineAssociation

    # �G���W�����[�g�i�ʃX�N���v�g�ŉ����A������Ȃ���΃G���[�j
    $resolveScript = Join-Path $PSScriptRoot 'Get-UEInstallPath.ps1'
    if (-not (Test-Path -LiteralPath $resolveScript)) {
        throw "Get-UEInstallPath.ps1 ��������܂���B�G���W���p�X�������ł��܂���B"
    }
    $resolvedEngineRoot = & $resolveScript -Version $UEVersion
    if (-not $resolvedEngineRoot) {
        throw ("�}�j�t�F�X�g���� UE_{0} �̃C���X�g�[���悪������܂���ł����B" -f $UEVersion)
    }
    if (-not (Test-Path $resolvedEngineRoot)) {
        throw ("Unreal Engine {0} �̃f�B���N�g�������݂��܂���: {1}" -f $UEVersion, $resolvedEngineRoot)
    }

    $buildBat = Join-Path $resolvedEngineRoot 'Engine\\Build\\BatchFiles\\Build.bat'
    $editorExe = Join-Path $resolvedEngineRoot 'Engine\\Binaries\\Win64\\UnrealEditor.exe'

    if (-not (Test-Path $buildBat)) { throw "Build.bat ��������܂���: $buildBat" }
    if (-not (Test-Path $editorExe)) { throw "UnrealEditor.exe ��������܂���: $editorExe" }

    # �r���h�iEditor �^�[�Q�b�g�j
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

    Write-Info "�r���h�J�n: $editorTarget $Platform $Configuration"
    Write-Info "Engine: $resolvedEngineRoot"
    Write-Info "Project: $uprojectPath"

    $buildProc = Start-Process -FilePath $buildBat -ArgumentList $buildArgs -NoNewWindow -PassThru -Wait
    $exitCode = $buildProc.ExitCode

    if ($exitCode -ne 0) {
        Write-Err "�r���h�Ɏ��s���܂����BExitCode=$exitCode"
        exit $exitCode
    }

    Write-Info '�r���h�����BUnreal Editor ���N�����܂��B'
    $editorArgs = '"' + $uprojectPath + '"'
    Start-Process -FilePath $editorExe -ArgumentList $editorArgs | Out-Null
}
catch {
    Write-Err $_.Exception.Message
    exit 1
}

