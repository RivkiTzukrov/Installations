param(
    [Parameter(Mandatory)][string]$SessionId,
    [Parameter(Mandatory)][string]$ApiBaseUrl
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Post-Update {
    param([string]$Id, [string]$Status, [string]$Message)
    
    $body = @{
        session_id = $SessionId
        app = $Id
        status = $Status
        log = $Message
    } | ConvertTo-Json -Compress
    
    try {
        Invoke-RestMethod -Uri "$ApiBaseUrl/sessions/update" -Method Post -Body $body -ContentType 'application/json' -TimeoutSec 10
    }
    catch {
        Write-Warning "Failed to update status for $Id`: $($_.Exception.Message)"
    }
}

function Get-SessionData {
    try {
        return Invoke-RestMethod -Uri "$ApiBaseUrl/sessions/json/$SessionId" -TimeoutSec 30
    }
    catch {
        Write-Error "Failed to fetch session data: $_"
        exit 1
    }
}

function Install-Application {
    param($App)
    
    $id = $App.id
    $tmpFile = "$env:TEMP\$id-installer"
    
    Post-Update $id "starting" "Downloading $id"
    
    try {
        Invoke-RestMethod -Uri $App.url -OutFile $tmpFile -TimeoutSec 300
    }
    catch {
        Post-Update $id "error" "Download failed: $_"
        return
    }
    
    Post-Update $id "running" "Installing $id"
    
    try {
        switch ($App.installer_type) {
            'exe' { 
                Start-Process -FilePath $tmpFile -ArgumentList $App.args -Wait -NoNewWindow
            }
            'msi' { 
                $msiArgs = "/i `"$tmpFile`" $($App.args) /qn /norestart"
                Start-Process msiexec.exe -ArgumentList $msiArgs -Wait -NoNewWindow
            }
            'zip' {
                $dest = "$env:ProgramFiles\$id"
                if (Test-Path $dest) { Remove-Item $dest -Recurse -Force }
                Expand-Archive -Path $tmpFile -DestinationPath $dest -Force
                
                if ($App.add_to_path) {
                    $binPath = "$dest\bin"
                    if (Test-Path $binPath) { $pathToAdd = $binPath } else { $pathToAdd = $dest }
                    $currentPath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
                    if ($currentPath -notlike "*$pathToAdd*") {
                        [Environment]::SetEnvironmentVariable('Path', "$currentPath;$pathToAdd", 'Machine')
                        Post-Update $id "info" "Added $pathToAdd to PATH"
                    }
                }
                
                # Set HOME environment variables
                if ($App.env_vars) {
                    foreach ($varName in $App.env_vars) {
                        [Environment]::SetEnvironmentVariable($varName, $dest, 'Machine')
                        Post-Update $id "info" "Set $varName = $dest"
                    }
                }
            }
            default {
                throw "Unsupported installer type: $($App.installer_type)"
            }
        }
        
        # Handle JetBrains activation
        if ($App.type -eq 'jetbrains' -and $App.activation_code) {
            $configDir = "$env:APPDATA\JetBrains\$id"
            if (-not (Test-Path $configDir)) { New-Item -Path $configDir -ItemType Directory -Force }
            Set-Content -Path "$configDir\activation.code" -Value $App.activation_code -Force
            Post-Update $id "info" "Activation code applied"
        }
        
        # Execute post-installation commands
        if ($App.commands) {
            Post-Update $id "info" "Running post-installation commands"
            foreach ($cmd in $App.commands) {
                try {
                    Invoke-Expression $cmd
                    Post-Update $id "info" "Command executed: $cmd"
                }
                catch {
                    Post-Update $id "warning" "Command failed: $cmd - $_"
                }
            }
        }
        
        Post-Update $id "success" "$id installed successfully"
    }
    catch {
        Post-Update $id "error" "Installation failed: $_"
    }
    finally {
        if (Test-Path $tmpFile) {
            Remove-Item $tmpFile -Force -ErrorAction SilentlyContinue
        }
    }
}

# Main execution
$sessionData = Get-SessionData

foreach ($app in $sessionData.apps) {
    Install-Application $app
}

Post-Update "system" "info" "All installations completed"