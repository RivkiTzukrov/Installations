"""
Unified Installation Manager - Simple, Efficient, Single-Port
Organized for clarity and maintainability
"""

import json
import uuid
from datetime import datetime
from typing import List
from pathlib import Path
from fastapi import FastAPI, HTTPException, Request
from fastapi.responses import HTMLResponse
from pydantic import BaseModel
import uvicorn

# --- Data Models ---
class LogUpdate(BaseModel):
    session_id: str
    app: str
    status: str
    log: str = ""

# --- App Setup ---
app = FastAPI(title="Installation Manager")

# --- In-Memory Storage (thread-safe for simple use) ---
sessions = {}
logs = {}

# --- Utility Functions ---
def load_manifest():
    """Load applications from manifest.json"""
    try:
        with open(Path(__file__).parent / "manifest.json") as f:
            return json.load(f)["applications"]
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to load manifest: {e}")

# --- API Endpoints ---
@app.post("/api/create-session")
def create_session(selected_apps: List[str]):
    session_id = str(uuid.uuid4())
    all_apps = {app["id"]: app for app in load_manifest()}
    session_apps = [all_apps[app_id] for app_id in selected_apps if app_id in all_apps]
    sessions[session_id] = {"id": session_id, "apps": session_apps}
    logs[session_id] = []
    return {"session_id": session_id}

@app.get("/sessions/json/{session_id}")
def get_session(session_id: str):
    if session_id not in sessions:
        raise HTTPException(status_code=404, detail="Session not found")
    return sessions[session_id]

@app.post("/sessions/update")
def add_log(update: LogUpdate):
    if update.session_id not in logs:
        raise HTTPException(status_code=404, detail="Session not found")
    log_entry = {
        "time": datetime.now().strftime("%H:%M:%S"),
        "app": update.app,
        "status": update.status,
        "message": update.log
    }
    logs[update.session_id].append(log_entry)
    return {"ok": True}

@app.get("/api/sessions/{session_id}/logs")
def get_logs(session_id: str):
    return {"logs": logs.get(session_id, [])}

@app.get("/api/apps")
def get_apps():
    return {"apps": load_manifest()}

# --- Web UI Endpoints ---
@app.get("/", response_class=HTMLResponse)
def home():
    return (Path(__file__).parent / "templates" / "index.html").read_text(encoding="utf-8")

@app.get("/session/{session_id}", response_class=HTMLResponse)
def session_page(session_id: str):
    if session_id not in sessions:
        return "<h1>Session not found</h1>"
    html = (Path(__file__).parent / "templates" / "session.html").read_text(encoding="utf-8")
    return html.replace("{{SESSION_ID}}", session_id)

if __name__ == "__main__":
    print("\n🚀 Installation Manager running on http://localhost:8000\n")
    uvicorn.run("main:app", host="0.0.0.0", port=8000, log_level="warning", reload=True)
