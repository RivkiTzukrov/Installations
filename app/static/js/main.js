let ubuntuManuallySelected = false;

async function loadApps() {
    const resp = await fetch('/api/apps');
    const data = await resp.json();
    const appList = document.getElementById('app-list');
    appList.innerHTML = data.apps.map(app => `
        <div class="app-item" onclick="toggleApp('${app.id}')">
            <input type="checkbox" name="apps" value="${app.id}" onchange="handleAppSelection('${app.id}', this.checked)">
            <div class="app-name">${app.name}</div>
            <div class="app-version">${app.version} • ${app.installer_type}</div>
        </div>
    `).join('');
}

function selectAll() {
    document.querySelectorAll('input[name="apps"]').forEach(cb => {
        cb.checked = true;
        cb.closest('.app-item').classList.add('selected');
    });
}

function selectNone() {
    document.querySelectorAll('input[name="apps"]').forEach(cb => {
        cb.checked = false;
        cb.closest('.app-item').classList.remove('selected');
    });
    enableApp('wsl');
    enableApp('ubuntu');
    ubuntuManuallySelected = false;
}

function handleAppSelection(appId, isChecked) {
    if (appId === 'ubuntu' && isChecked) {
        document.getElementById('ubuntuModal').style.display = 'block';
    }
    
    if (isChecked) {
        if (appId === 'wsl') {
            selectDependencies(['ubuntu'], 'WSL requires Ubuntu');
        } else if (appId === 'docker-desktop') {
            selectDependencies(['wsl', 'ubuntu'], 'Docker requires WSL and Ubuntu');
        }
    }
    
    updateDependencyLocks();
}

function selectDependencies(deps, message) {
    let added = [];
    deps.forEach(depId => {
        const checkbox = document.querySelector(`input[value="${depId}"]`);
        if (checkbox && !checkbox.checked) {
            checkbox.checked = true;
            checkbox.closest('.app-item').classList.add('selected');
            added.push(depId);
            if (depId === 'ubuntu' && !ubuntuManuallySelected) {
                document.getElementById('ubuntuModal').style.display = 'block';
                ubuntuManuallySelected = true;
            }
        }
    });
    if (added.length > 0) {
        showNotification(message);
    }
}

function updateDependencyLocks() {
    const dockerSelected = document.querySelector('input[value="docker-desktop"]').checked;
    const wslSelected = document.querySelector('input[value="wsl"]').checked;
    
    if (dockerSelected) {
        disableApp('wsl');
        disableApp('ubuntu');
    } else if (wslSelected) {
        disableApp('ubuntu');
        enableApp('wsl');
    } else {
        enableApp('wsl');
        enableApp('ubuntu');
    }
}

function disableApp(appId) {
    const appItem = document.querySelector(`input[value="${appId}"]`).closest('.app-item');
    appItem.classList.add('disabled');
}

function enableApp(appId) {
    const appItem = document.querySelector(`input[value="${appId}"]`).closest('.app-item');
    appItem.classList.remove('disabled');
}

function showNotification(message) {
    const notification = document.createElement('div');
    notification.className = 'notification';
    notification.textContent = message;
    document.body.appendChild(notification);
    setTimeout(() => notification.classList.add('show'), 100);
    setTimeout(() => {
        notification.classList.remove('show');
        setTimeout(() => document.body.removeChild(notification), 300);
    }, 3000);
}

function closeModal() {
    document.getElementById('ubuntuModal').style.display = 'none';
}

function toggleApp(appId) {
    const checkbox = document.querySelector(`input[value="${appId}"]`);
    const appItem = checkbox.closest('.app-item');
    
    if (appItem.classList.contains('disabled')) {
        return;
    }
    
    checkbox.checked = !checkbox.checked;
    appItem.classList.toggle('selected', checkbox.checked);
    handleAppSelection(appId, checkbox.checked);
}

async function createSession() {
    const selected = Array.from(document.querySelectorAll('input[name="apps"]:checked')).map(cb => cb.value);
    if (selected.length === 0) {
        alert('Please select at least one application');
        return;
    }
    
    const response = await fetch('/api/create-session', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(selected)
    });
    
    const data = await response.json();
    if (response.ok) {
        document.getElementById('sessionId').textContent = data.session_id;
        const command = `powershell.exe -ExecutionPolicy Bypass -Command "$f='$env:TEMP\\\\install.ps1'; Invoke-RestMethod '${data.s3_url}' -OutFile $f; & $f -SessionId '${data.session_id}' -ApiBaseUrl '${window.location.origin}'"`;
        document.getElementById('psCommand').innerHTML = `${command}<button class="copy-btn" onclick="copyCommand()" title="Copy command">📋</button>`;
        document.getElementById('sessionLink').href = `/session/${data.session_id}`;
        document.getElementById('result').classList.remove('hidden');
    } else {
        alert('Error: ' + (data.detail || 'Unknown error'));
    }
}

function copyCommand() {
    const commandElement = document.getElementById('psCommand');
    const command = commandElement.textContent.replace('Copy', '').trim();
    navigator.clipboard.writeText(command).then(() => {
        const btn = document.querySelector('.copy-btn');
        btn.textContent = '✓';
        setTimeout(() => {
            btn.textContent = '📋';
        }, 1000);
    });
}

function showSupportModal() {
    alert('Support: For technical assistance, please contact solid-team@company.com or visit our documentation.');
}

function showAboutModal() {
    alert('Installation Manager v1.0\\nDeveloped by SOLID Team\\nDesigned for offline software deployment in enterprise environments.');
}

window.onload = loadApps;