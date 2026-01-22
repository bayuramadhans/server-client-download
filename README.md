# File Download System

A cloud-based file download system that enables secure file transfers from on-premise clients to a cloud server. The system uses WebSocket connections to work seamlessly behind NAT/firewall, with REST API endpoints for triggering and monitoring downloads.

## Overview

This project simulates a scenario where:
- **Server**: A cloud-based server that clients connect to via WebSocket
- **Clients**: On-premise clients (e.g., restaurant locations) behind NAT/firewalls that initiate outbound connections
- **Files**: 100MB test files that are downloaded from clients in chunks

The system supports:
- Multiple concurrent client connections
- Real-time download progress monitoring
- File integrity verification via checksums
- Docker containerization for easy deployment

## Project Structure

```
├── server.py                    # Cloud server implementation
├── client.py                    # On-premise client implementation
├── docker-compose.yml          # Docker orchestration
├── Dockerfile.server           # Server container configuration
├── Dockerfile.client           # Client container configuration
├── requirements.txt            # Python dependencies
├── setup.sh                    # Initial setup script
├── setup.bat                   # Windows setup script
├── test-guide.sh              # Interactive testing guide
├── test-guide.bat             # Windows testing guide
├── checksums.txt              # File integrity checksums (generated)
├── test-files/                # Test files to download
│   ├── restaurant-001/
│   │   └── file_to_download.txt (100MB)
│   ├── restaurant-002/
│   │   └── file_to_download.txt (100MB)
│   └── restaurant-003/
│       └── file_to_download.txt (100MB)
└── downloads/                 # Downloaded files (generated)
```

## Prerequisites

- **Linux/macOS**: Bash shell
- **Windows**: Git Bash, WSL, or PowerShell
- **Docker** and **Docker Compose**
- **Python 3.8+** (for standalone testing without Docker)

## Setup

### Step 1: Run the Setup Script

First, initialize the project by running the setup script. This will:
- Create the required directory structure
- Generate 100MB test files for each client (restaurant-001, restaurant-002, restaurant-003)
- Calculate MD5 checksums for file integrity verification
- Set appropriate permissions

**On Linux/macOS:**
```bash
bash setup.sh
```

**On Windows (PowerShell/Git Bash):**
```bash
bash setup.sh
```

The setup process will create three 100MB test files in the `test-files/` directory and save their checksums to `checksums.txt`.

## Testing

### Step 2: Run the Testing Guide

After setup completes, use the interactive testing guide to test the system:

**On Linux/macOS:**
```bash
bash test-guide.sh
```

**On Windows:**
```bash
bash test-guide.sh
```

### Available Test Options

The testing guide provides the following interactive menu:

1. **Check system health** - Verify server and connected clients status
2. **List connected clients** - View all registered clients
3. **Download file from restaurant-001** - Trigger download from specific client
4. **Download file from restaurant-002** - Trigger download from specific client
5. **Download file from restaurant-003** - Trigger download from specific client
6. **Download from all clients** - Trigger downloads from all three clients
7. **Check download status** - Monitor specific download progress
8. **Verify downloaded files (checksums)** - Verify file integrity
9. **View server logs** - Display server container logs
10. **View client logs** - Display specific client container logs
11. **Clean up downloads** - Remove downloaded files
12. **Exit** - Close the testing guide

## Quick Start

### Complete Setup and Testing Flow

```bash
# 1. Clone or navigate to the project directory
cd server-client-download

# 2. Run setup (creates test files and calcums)
bash setup.sh

# 3. Start Docker containers
docker-compose up --build

# 4. In another terminal, run the testing guide
bash test-guide.sh
```

## Architecture

### Server (`server.py`)
- Runs on port 8080
- Accepts WebSocket connections from clients
- Provides REST API for triggering and monitoring downloads
- Stores downloaded files in the `downloads/` directory
- Tracks download progress per file

### Clients (`client.py`)
- Connects to server via WebSocket
- Registers with a unique client ID (e.g., restaurant-001)
- Listens for file download requests
- Sends files in configurable chunks (default: 1MB)
- Reports progress to server

### Key Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/health` | Server health check |
| GET | `/api/clients` | List connected clients |
| POST | `/api/download` | Trigger a file download |
| GET | `/api/downloads/{id}` | Get download status |
| WebSocket | `/ws` | Client connection endpoint |

## Configuration

### Environment Variables

The system can be configured via Docker environment variables. See `docker-compose.yml` for current settings.

### File Chunk Size

The default chunk size is 1MB. This can be modified in:
- `client.py`: `chunk_size` parameter (line ~20)
- `docker-compose.yml`: Environment variable settings

## Features

✓ **WebSocket-based communication** - Works behind NAT/firewalls  
✓ **Chunked file transfer** - Efficient handling of large files  
✓ **Real-time progress tracking** - Monitor download status in real-time  
✓ **Checksum verification** - Ensure file integrity  
✓ **Docker containerization** - Easy deployment and testing  
✓ **REST API** - Simple HTTP interface for downloads  
✓ **Multi-client support** - Handle multiple concurrent clients  
✓ **Interactive testing guide** - User-friendly CLI for testing  

## Troubleshooting

### Files not downloading
- Ensure all containers are running: `docker-compose ps`
- Check server logs: `docker-compose logs server`
- Verify client registration: Use menu option 2 in test-guide.sh

### Checksum mismatch
- Files may be corrupted during transfer
- Try downloading again
- Check Docker container logs for errors

### Port already in use
- Change the port in `docker-compose.yml`
- Or stop other services using port 8080

### Test files not created
- Run `setup.sh` with sudo if permission denied
- Ensure you have at least 300MB free disk space (3 × 100MB files)

## Dependencies

See [requirements.txt](requirements.txt) for Python dependencies:
- aiohttp: Async HTTP client/server
- asyncio: Built-in Python async library

## License

Internal project

## Support

For issues or questions, refer to the logs:
```bash
# Server logs
docker-compose logs server

# Client logs
docker-compose logs client-restaurant-001
docker-compose logs client-restaurant-002
docker-compose logs client-restaurant-003

# All logs
docker-compose logs
```
