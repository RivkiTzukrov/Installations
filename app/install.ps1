param(
    [Parameter(Mandatory)][string]$SessionId,
    [Parameter(Mandatory)][string]$ApiBaseUrl
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Post-Update {
    param([string]$Id, [string]$Status, [string]$Message)
    $body = @{ session_id=$SessionId; app=$Id; status=$Status; log=$Message } | ConvertTo-Json -Compress
    try { Invoke-RestMethod -Uri "$ApiBaseUrl/sessions/update" -Method Post -Body $body -ContentType 'application/json' -TimeoutSec 10 }
    catch { Write-Warning "Failed to update $Id`: $_" }
}

try {
    $sessionJson = Invoke-RestMethod -Uri "$ApiBaseUrl/sessions/json/$SessionId" -TimeoutSec 30
} catch {
    Write-Error "Failed to fetch session data: $_"
    exit 1
}

foreach ($app in $sessionJson.apps) {
    $id = $app.id
    $tmp = "$env:TEMP\$id-installer"
    
    Post-Update $id "starting" "Downloading $id"
    
    try {
        Invoke-RestMethod -Uri $app.url -OutFile $tmp -TimeoutSec 300
    } catch {
        Post-Update $id "error" "Download failed: $_"
        continue
    }

    Post-Update $id "running" "Installing $id"
    try {
        switch ($app.installer_type) {
            'exe' { 
                Start-Process -FilePath $tmp -ArgumentList $app.args -Wait -NoNewWindow
            }
            'msi' { 
                Start-Process msiexec.exe -ArgumentList "/i `"$tmp`" $($app.args) /qn /norestart" -Wait -NoNewWindow
            }
            'zip' {
                $dest = "$env:ProgramFiles\$id"
                if (Test-Path $dest) { Remove-Item $dest -Recurse -Force }
                Expand-Archive -Path $tmp -DestinationPath $dest -Force
                
                if ($app.add_to_path) {
                    $currentPath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
                    if ($currentPath -notlike "*$dest*") {
                        [Environment]::SetEnvironmentVariable('Path', "$currentPath;$dest", 'Machine')
                        Post-Update $id "info" "Added $dest to PATH"
                    }
                }
            }
            default { throw "Unsupported installer type: $($app.installer_type)" }
        }

        # Execute post-installation commands
        if ($app.commands) {
            Post-Update $id "info" "Running post-installation commands"
            foreach ($cmd in $app.commands) {
                try {
                    Invoke-Expression $cmd
                    Post-Update $id "info" "Command executed: $cmd"
                } catch {
                    Post-Update $id "warning" "Command failed: $cmd - $_"
                }
            }
        }
        
        Post-Update $id "success" "$id installed successfully"
    } catch {
        Post-Update $id "error" "Installation failed: $_"
    } finally {
        if (Test-Path $tmp) {
            Remove-Item $tmp -Force -ErrorAction SilentlyContinue
        }
    }
}
