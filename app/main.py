import json
import uuid
import html
from datetime import datetime, timezone
from typing import List, Dict, Any
from pathlib import Path
from fastapi import FastAPI, HTTPException
from fastapi.responses import HTMLResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel
import uvicorn

class LogUpdate(BaseModel):
    session_id: str
    app: str
    status: str
    log: str = ""

app = FastAPI(title="Installation Manager")
app.mount("/static", StaticFiles(directory=Path(__file__).parent / "static"), name="static")

sessions: Dict[str, Dict[str, Any]] = {}
logs: Dict[str, List[Dict[str, str]]] = {}

try:
    with open(Path(__file__).parent / "manifest.json") as f:
        MANIFEST = json.load(f)["applications"]
except Exception as e:
    raise RuntimeError(f"Failed to load manifest: {e}")

@app.post("/api/create-session")
def create_session(selected_apps: List[str]):
    if not selected_apps:
        raise HTTPException(status_code=400, detail="No applications selected")
    
    session_id = str(uuid.uuid4())
    all_apps = {app["id"]: app for app in MANIFEST}
    session_apps = [all_apps[app_id] for app_id in selected_apps if app_id in all_apps]
    
    if not session_apps:
        raise HTTPException(status_code=400, detail="No valid applications found")
    
    sessions[session_id] = {"id": session_id, "apps": session_apps}
    logs[session_id] = []
    return {
        "session_id": session_id,
        "s3_url": "https://solid-team-installers.s3.amazonaws.com/install.ps1"
    }

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
        "time": datetime.now(timezone.utc).strftime("%H:%M:%S"),
        "app": html.escape(update.app),
        "status": html.escape(update.status),
        "message": html.escape(update.log)
    }
    logs[update.session_id].append(log_entry)
    return {"ok": True}

@app.get("/api/sessions/{session_id}/logs")
def get_logs(session_id: str):
    return {"logs": logs.get(session_id, [])}

@app.get("/api/apps")
def get_apps():
    return {"apps": MANIFEST}

@app.get("/", response_class=HTMLResponse)
def home():
    try:
        return (Path(__file__).parent / "templates" / "index.html").read_text(encoding="utf-8")
    except FileNotFoundError:
        raise HTTPException(status_code=500, detail="Template not found")
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Template error: {e}")

@app.get("/session/{session_id}", response_class=HTMLResponse)
def session_page(session_id: str):
    try:
        uuid.UUID(session_id)
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid session ID format")
    
    if session_id not in sessions:
        raise HTTPException(status_code=404, detail="Session not found")
    
    try:
        html_content = (Path(__file__).parent / "templates" / "session.html").read_text(encoding="utf-8")
        safe_session_id = html.escape(session_id)
        return html_content.replace("{{SESSION_ID}}", safe_session_id)
    except FileNotFoundError:
        raise HTTPException(status_code=500, detail="Template not found")
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Template error: {e}")

if __name__ == "__main__":
    print("🚀 Installation Manager running on http://localhost:8000")
    uvicorn.run("main:app", host="0.0.0.0", port=8000, log_level="info", reload=False)
