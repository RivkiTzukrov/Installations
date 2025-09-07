# Installation Manager

A web-based software installation manager designed for **offline environments** that allows users to select and install multiple applications on Windows systems through PowerShell automation. All software packages are hosted on an S3 bucket for reliable access.

## Features

- **Modern Web UI**: Clean, minimal interface for selecting applications
- **Batch Installation**: Install multiple applications in a single session
- **Real-time Progress**: Monitor installation progress with live logs
- **Dependency Management**: Automatically selects required dependencies (WSL → Ubuntu, Docker → WSL + Ubuntu)
- **PowerShell Integration**: Generates PowerShell commands for automated installation
- **Session Management**: Track installation sessions with unique IDs

## How It Works

1. **Select Applications**: Users choose from a grid of available software (Docker, VSCode, Python, etc.)
2. **Create Session**: System generates a unique installation session with PowerShell command
3. **Run Installation**: Users execute the PowerShell command as Administrator
4. **Monitor Progress**: Real-time logs show installation status for each application

## Architecture

- **Backend**: FastAPI Python server (`main.py`)
- **Frontend**: Modern HTML/CSS/JavaScript with minimal design
- **Configuration**: JSON manifest defining available applications (`manifest.json`)
- **Installation**: PowerShell script automation (`install.ps1`)
- **Storage**: All software packages hosted on S3 bucket for offline access

## Key Components

### Web Interface
- **Main Page** (`index.html`): Application selection grid with dependency logic
- **Progress Page** (`session.html`): Real-time installation monitoring
- **Modal Notifications**: Ubuntu setup warnings and dependency alerts

### Application Management
- **Manifest System**: JSON configuration for all available software
- **Dependency Resolution**: Auto-selects WSL/Ubuntu when needed
- **Installation Types**: Supports EXE, MSI, ZIP installers

### Special Features
- **Ubuntu Setup Warning**: Alerts users about username/password requirement
- **Copy Commands**: One-click PowerShell command copying
- **Auto-refresh Logs**: Live updates during installation process

## Usage

1. Start the server: `python main.py`
2. Open browser to `http://localhost:8000`
3. Select desired applications
4. Copy and run the generated PowerShell command as Administrator
5. Monitor progress on the session page

## Dependencies

- FastAPI for web server
- Modern web browser
- Windows PowerShell
- Administrator privileges for installations
- Access to S3 bucket containing software packages

## Offline Environment

This system is specifically designed for offline or restricted network environments where direct software downloads are not possible. All installation packages are pre-hosted on an S3 bucket, ensuring reliable access to software without requiring internet connectivity to vendor websites.