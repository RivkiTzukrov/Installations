let autoRefreshInterval;
// sessionId is defined in the HTML template

async function refreshLogs() {
    try {
        const response = await fetch(`/api/sessions/${sessionId}/logs`);
        const data = await response.json();
        const logsContainer = document.getElementById('logs');
        
        if (data.logs && data.logs.length > 0) {
            const isAtBottom = logsContainer.scrollTop >= logsContainer.scrollHeight - logsContainer.clientHeight - 50;
            
            logsContainer.innerHTML = data.logs.map(log => `
                <div class="log-entry">
                    <div class="status-circle ${log.status}"></div>
                    <div class="log-content">
                        <div class="log-header">
                            <span class="app-name">${log.app}</span>
                            <span class="status-pill ${log.status}">${log.status}</span>
                            <span class="timestamp">${log.time}</span>
                        </div>
                        <div class="log-message">${log.message}</div>
                    </div>
                </div>
            `).join('');
            
            if (isAtBottom) {
                logsContainer.scrollTop = logsContainer.scrollHeight;
            }
        }
    } catch (error) {
        console.error('Failed to refresh logs:', error);
    }
}

function toggleAutoRefresh() {
    const checkbox = document.getElementById('autoRefresh');
    
    if (checkbox.checked) {
        autoRefreshInterval = setInterval(refreshLogs, 3000);
    } else {
        clearInterval(autoRefreshInterval);
    }
}

// Initialize
toggleAutoRefresh();
refreshLogs();