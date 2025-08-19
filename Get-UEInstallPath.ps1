Param(
    [Parameter(Mandatory = $true)]
    [string]$Version
)

$ErrorActionPreference = 'Stop'

function Write-Warn {
    param([string]$Message)
    Write-Host "[WARN] $Message" -ForegroundColor Yellow
}

try {
    $appName = "UE_$Version"
    $manifestPath = 'C:\ProgramData\Epic\EpicGamesLauncher\Data\Manifests'

    if (-not (Test-Path -LiteralPath $manifestPath)) {
        throw "�}�j�t�F�X�g�f�B���N�g����������܂���: $manifestPath"
    }

    $itemFiles = Get-ChildItem -Path $manifestPath -Filter *.item -File -ErrorAction Stop
    foreach ($file in $itemFiles) {
        try {
            $json = Get-Content -LiteralPath $file.FullName -Raw | ConvertFrom-Json
            if ($null -ne $json -and $json.AppName -eq $appName -and $null -ne $json.InstallLocation -and $json.InstallLocation -ne '') {
                Write-Output $json.InstallLocation
                return
            }
        } catch {
            Write-Warn "�}�j�t�F�X�g�̉�͂Ɏ��s: $($file.Name) - $($_.Exception.Message)"
        }
    }

    throw ("�}�j�t�F�X�g���� UE_{0} �̃C���X�g�[���悪������܂���ł����B" -f $Version)
} catch {
    throw ("�}�j�t�F�X�g�����ŗ�O: {0}" -f $_.Exception.Message)
}
