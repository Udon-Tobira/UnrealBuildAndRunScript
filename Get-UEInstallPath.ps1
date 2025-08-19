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
        throw "マニフェストディレクトリが見つかりません: $manifestPath"
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
            Write-Warn "マニフェストの解析に失敗: $($file.Name) - $($_.Exception.Message)"
        }
    }

    throw ("マニフェストから UE_{0} のインストール先が見つかりませんでした。" -f $Version)
} catch {
    throw ("マニフェスト走査で例外: {0}" -f $_.Exception.Message)
}
