param(
    [Parameter(Mandatory)] [string] $SessionId,
    [Parameter(Mandatory)] [string]    $ApiBaseUrl
)

function Post-Update { param($id,$status,$msg)
    $body = @{ session_id=$SessionId; app=$id; status=$status; log=$msg } | ConvertTo-Json
    try { Invoke-RestMethod -Uri "$ApiBaseUrl/sessions/update" -Method Post -Body $body -ContentType 'application/json' }
    catch { Write-Warning "POST update failed for $id: $($_.Exception.Message)" }
}

# Download session manifest
try { $sessionJson = Invoke-RestMethod -Uri "$ApiBaseUrl/sessions/json/$SessionId" }
catch { Write-Error "Failed to fetch session JSON: $_"; exit 1 }

foreach ($app in $sessionJson.apps) {
    $id = $app.id; $url = $app.url; $type = $app.installer_type
    $args = $app.args; $expectedHash = $app.sha256
    Post-Update $id "starting" "Downloading $id"
    $tmp = "$env:TEMP\$id-installer"

    try { Invoke-RestMethod -Uri $url -OutFile $tmp }
    catch { Post-Update $id "error" "Download failed: $_"; continue }

    if ($expectedHash) {
        try {
            $actual = (Get-FileHash -Path $tmp -Algorithm SHA256).Hash.ToLower()
            if ($actual -ne $expectedHash.ToLower()) {
                Post-Update $id "error" "Hash mismatch: $actual"
                continue
            } else { Post-Update $id "info" "Hash verified" }
        } catch { Post-Update $id "error" "Hash check failed: $_"; continue }
    }

    Post-Update $id "running" "Installing $id"
    try {
        switch ($type) {
            'exe' { Start-Process -FilePath $tmp -ArgumentList $args -Wait }
            'msi' { Start-Process msiexec.exe -ArgumentList "/i `"$tmp`" $args /qn /norestart" -Wait }
            'zip' {
                $dest = "$env:ProgramFiles\$id"
                Expand-Archive -Path $tmp -DestinationPath $dest -Force
                if ($app.add_to_path) {
                    [Environment]::SetEnvironmentVariable('Path',
                        [Environment]::GetEnvironmentVariable('Path','Machine') + ";$dest",
                        'Machine')
                    Post-Update $id "info" "Added $dest to PATH"
                }
            }
        }

        # Handle JetBrains activation
        if ($app.type -eq 'jetbrains' -and $app.activation_code) {
            $config = "$env:APPDATA\JetBrains\$($app.id)\activation.code"
            Set-Content -Path $config -Value $app.activation_code -Force
            Post-Update $id "info" "Activation code applied"
        }

        # Execute post-installation commands
        if ($app.commands) {
            Post-Update $id "info" "Running post-installation commands"
            foreach ($cmd in $app.commands) {
                try {
                    & powershell -NoProfile -Command $cmd
                    Post-Update $id "info" "Command executed: $cmd"
                } catch {
                    Post-Update $id "warning" "Command failed: $cmd - $_"
                }
            }
        }

        Post-Update $id "success" "$id installed"
    } catch {
        Post-Update $id "error" "Install failed: $_"
    } finally {
        Remove-Item $tmp -Force -ErrorAction Silently
        
    }
}
