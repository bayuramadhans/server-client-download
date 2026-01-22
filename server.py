#!/usr/bin/env python3
"""
Cloud Server for downloading files from on-premise clients.
Supports both REST API and CLI for triggering downloads.
"""

import asyncio
import json
import os
import uuid
from datetime import datetime
from pathlib import Path
from typing import Dict, Optional

import aiohttp
from aiohttp import web
import argparse


class FileDownloadServer:
    def __init__(self, host='0.0.0.0', port=8080, download_dir='./downloads'):
        self.host = host
        self.port = port
        self.download_dir = Path(download_dir)
        self.download_dir.mkdir(exist_ok=True)
        
        # Track connected clients: {client_id: websocket}
        self.connected_clients: Dict[str, web.WebSocketResponse] = {}
        
        # Track ongoing downloads: {download_id: {status, file_path, etc}}
        self.downloads: Dict[str, dict] = {}
        
        self.app = web.Application()
        self.setup_routes()
    
    def setup_routes(self):
        """Setup HTTP and WebSocket routes"""
        self.app.router.add_get('/ws', self.websocket_handler)
        self.app.router.add_post('/api/download', self.trigger_download)
        self.app.router.add_get('/api/downloads/{download_id}', self.get_download_status)
        self.app.router.add_get('/api/clients', self.list_clients)
        self.app.router.add_get('/health', self.health_check)
    
    async def health_check(self, request):
        """Health check endpoint"""
        return web.json_response({
            'status': 'healthy',
            'connected_clients': len(self.connected_clients),
            'active_downloads': len([d for d in self.downloads.values() if d['status'] == 'downloading'])
        })
    
    async def list_clients(self, request):
        """List all connected clients"""
        clients = [
            {
                'client_id': client_id,
                'connected': True,
                'connected_at': 'N/A'  # Could track connection time
            }
            for client_id in self.connected_clients.keys()
        ]
        return web.json_response({'clients': clients})
    
    async def websocket_handler(self, request):
        """Handle WebSocket connections from clients"""
        # Increase max message size to handle large file chunks (1MB chunks = ~1.33MB when JSON encoded)
        # Using 16MB to be safe and allow for JSON overhead
        ws = web.WebSocketResponse(heartbeat=30, max_msg_size=16*1024*1024)
        await ws.prepare(request)
        
        client_id = None
        
        try:
            async for msg in ws:
                if msg.type == aiohttp.WSMsgType.TEXT:
                    data = json.loads(msg.data)
                    msg_type = data.get('type')
                    
                    if msg_type == 'register':
                        client_id = data.get('client_id')
                        self.connected_clients[client_id] = ws
                        print(f"✓ Client registered: {client_id}")
                        await ws.send_json({
                            'type': 'registered',
                            'message': 'Successfully registered'
                        })
                    
                    elif msg_type == 'file_chunk':
                        await self.handle_file_chunk(data)
                    
                    elif msg_type == 'file_complete':
                        await self.handle_file_complete(data)
                    
                    elif msg_type == 'error':
                        await self.handle_client_error(data)
                
                elif msg.type == aiohttp.WSMsgType.ERROR:
                    print(f'WebSocket error: {ws.exception()}')
        
        finally:
            if client_id and client_id in self.connected_clients:
                del self.connected_clients[client_id]
                print(f"✗ Client disconnected: {client_id}")
        
        return ws
    
    async def handle_file_chunk(self, data):
        """Handle incoming file chunk from client"""
        download_id = data.get('download_id')
        chunk_data = data.get('data')
        chunk_num = data.get('chunk_num')
        
        if download_id not in self.downloads:
            print(f"Warning: Received chunk for unknown download {download_id}")
            return
        
        download_info = self.downloads[download_id]
        file_path = download_info['file_path']
        
        # Append chunk to file
        with open(file_path, 'ab') as f:
            f.write(chunk_data.encode('latin1'))  # Preserve binary encoding
        
        download_info['chunks_received'] = chunk_num
        print(f"  Chunk {chunk_num} received for download {download_id}")
    
    async def handle_file_complete(self, data):
        """Handle file download completion"""
        download_id = data.get('download_id')
        total_size = data.get('total_size')
        
        if download_id in self.downloads:
            download_info = self.downloads[download_id]
            download_info['status'] = 'completed'
            download_info['completed_at'] = datetime.utcnow().isoformat()
            download_info['total_size'] = total_size
            
            print(f"✓ Download completed: {download_id}")
            print(f"  File saved to: {download_info['file_path']}")
            print(f"  Size: {total_size:,} bytes")
    
    async def handle_client_error(self, data):
        """Handle error from client"""
        download_id = data.get('download_id')
        error_msg = data.get('message')
        
        if download_id in self.downloads:
            self.downloads[download_id]['status'] = 'failed'
            self.downloads[download_id]['error'] = error_msg
            print(f"✗ Download failed: {download_id} - {error_msg}")
    
    async def trigger_download(self, request):
        """API endpoint to trigger file download from a client"""
        try:
            data = await request.json()
            client_id = data.get('client_id')
            file_path = data.get('file_path', '$HOME/file_to_download.txt')
            
            if not client_id:
                return web.json_response(
                    {'error': 'client_id is required'},
                    status=400
                )
            
            if client_id not in self.connected_clients:
                return web.json_response(
                    {'error': f'Client {client_id} is not connected'},
                    status=404
                )
            
            # Generate download ID
            download_id = str(uuid.uuid4())
            
            # Prepare download tracking
            local_filename = f"{client_id}_{datetime.utcnow().strftime('%Y%m%d_%H%M%S')}_file_to_download.txt"
            local_path = self.download_dir / local_filename
            
            self.downloads[download_id] = {
                'download_id': download_id,
                'client_id': client_id,
                'file_path': str(local_path),
                'remote_path': file_path,
                'status': 'downloading',
                'started_at': datetime.utcnow().isoformat(),
                'chunks_received': 0
            }
            
            # Send download command to client
            ws = self.connected_clients[client_id]
            await ws.send_json({
                'type': 'download_request',
                'download_id': download_id,
                'file_path': file_path
            })
            
            print(f"→ Download request sent to {client_id}")
            print(f"  Download ID: {download_id}")
            
            return web.json_response({
                'success': True,
                'download_id': download_id,
                'message': f'Download request sent to client {client_id}'
            })
        
        except Exception as e:
            return web.json_response(
                {'error': str(e)},
                status=500
            )
    
    async def get_download_status(self, request):
        """Get status of a specific download"""
        download_id = request.match_info['download_id']
        
        if download_id not in self.downloads:
            return web.json_response(
                {'error': 'Download not found'},
                status=404
            )
        
        return web.json_response(self.downloads[download_id])
    
    def run(self):
        """Start the server"""
        print(f"Starting File Download Server on {self.host}:{self.port}")
        print(f"Downloads will be saved to: {self.download_dir.absolute()}")
        print(f"\nEndpoints:")
        print(f"  WebSocket: ws://{self.host}:{self.port}/ws")
        print(f"  API: http://{self.host}:{self.port}/api/download")
        print(f"  Status: http://{self.host}:{self.port}/api/downloads/{{download_id}}")
        print(f"  Clients: http://{self.host}:{self.port}/api/clients")
        print(f"\nWaiting for clients to connect...")
        
        web.run_app(self.app, host=self.host, port=self.port)


async def cli_trigger_download(server_url: str, client_id: str, file_path: str = '$HOME/file_to_download.txt'):
    """CLI function to trigger download"""
    api_url = f"{server_url}/api/download"
    
    async with aiohttp.ClientSession() as session:
        payload = {
            'client_id': client_id,
            'file_path': file_path
        }
        
        try:
            async with session.post(api_url, json=payload) as resp:
                result = await resp.json()
                
                if resp.status == 200:
                    print(f"✓ Download triggered successfully")
                    print(f"  Download ID: {result['download_id']}")
                    print(f"  Client: {client_id}")
                    
                    # Poll for completion
                    download_id = result['download_id']
                    await poll_download_status(server_url, download_id)
                else:
                    print(f"✗ Error: {result.get('error', 'Unknown error')}")
        
        except Exception as e:
            print(f"✗ Failed to trigger download: {e}")


async def poll_download_status(server_url: str, download_id: str, interval: int = 2):
    """Poll download status until complete"""
    status_url = f"{server_url}/api/downloads/{download_id}"
    
    async with aiohttp.ClientSession() as session:
        while True:
            try:
                async with session.get(status_url) as resp:
                    if resp.status == 200:
                        status_data = await resp.json()
                        status = status_data.get('status')
                        
                        if status == 'completed':
                            print(f"\n✓ Download completed!")
                            print(f"  File saved to: {status_data.get('file_path')}")
                            print(f"  Size: {status_data.get('total_size', 'N/A')} bytes")
                            break
                        elif status == 'failed':
                            print(f"\n✗ Download failed: {status_data.get('error', 'Unknown error')}")
                            break
                        else:
                            print(f"  Status: {status} (chunks: {status_data.get('chunks_received', 0)})")
                
                await asyncio.sleep(interval)
            
            except Exception as e:
                print(f"Error polling status: {e}")
                break


def main():
    parser = argparse.ArgumentParser(description='File Download Server/CLI')
    subparsers = parser.add_subparsers(dest='command', help='Commands')
    
    # Server command
    server_parser = subparsers.add_parser('server', help='Start the server')
    server_parser.add_argument('--host', default='0.0.0.0', help='Server host')
    server_parser.add_argument('--port', type=int, default=8080, help='Server port')
    server_parser.add_argument('--download-dir', default='./downloads', help='Download directory')
    
    # Download command
    download_parser = subparsers.add_parser('download', help='Trigger a download')
    download_parser.add_argument('--server', default='http://localhost:8080', help='Server URL')
    download_parser.add_argument('--client-id', required=True, help='Client ID')
    download_parser.add_argument('--file-path', default='$HOME/file_to_download.txt', help='Remote file path')
    
    args = parser.parse_args()
    
    if args.command == 'server':
        server = FileDownloadServer(
            host=args.host,
            port=args.port,
            download_dir=args.download_dir
        )
        server.run()
    
    elif args.command == 'download':
        asyncio.run(cli_trigger_download(
            server_url=args.server,
            client_id=args.client_id,
            file_path=args.file_path
        ))
    
    else:
        parser.print_help()


if __name__ == '__main__':
    main()