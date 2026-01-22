#!/usr/bin/env python3
"""
On-Premise Client for connecting to cloud server and serving file downloads.
Runs behind NAT/firewall - initiates outbound WebSocket connection.
"""

import asyncio
import json
import os
import sys
from pathlib import Path
import argparse

import aiohttp


class FileDownloadClient:
    def __init__(self, server_url: str, client_id: str, chunk_size: int = 1024 * 1024):
        self.server_url = server_url
        self.client_id = client_id
        self.chunk_size = chunk_size  # 1MB chunks by default
        self.ws = None
        self.running = True
    
    async def connect(self):
        """Establish WebSocket connection to server"""
        ws_url = self.server_url.replace('http://', 'ws://').replace('https://', 'wss://')
        ws_url = f"{ws_url}/ws"
        
        print(f"Connecting to server: {ws_url}")
        print(f"Client ID: {self.client_id}")
        
        session = aiohttp.ClientSession()
        
        try:
            self.ws = await session.ws_connect(ws_url, heartbeat=30)
            
            # Register with server
            await self.ws.send_json({
                'type': 'register',
                'client_id': self.client_id
            })
            
            print("✓ Connected to server")
            
            # Listen for messages
            await self.message_loop()
        
        except Exception as e:
            print(f"✗ Connection failed: {e}")
        
        finally:
            if self.ws:
                await self.ws.close()
            await session.close()
    
    async def message_loop(self):
        """Listen for messages from server"""
        print("Listening for download requests...")
        
        try:
            async for msg in self.ws:
                if msg.type == aiohttp.WSMsgType.TEXT:
                    data = json.loads(msg.data)
                    msg_type = data.get('type')
                    
                    if msg_type == 'registered':
                        print(f"✓ {data.get('message')}")
                    
                    elif msg_type == 'download_request':
                        await self.handle_download_request(data)
                    
                    elif msg_type == 'ping':
                        await self.ws.send_json({'type': 'pong'})
                
                elif msg.type == aiohttp.WSMsgType.CLOSED:
                    print("Connection closed by server")
                    break
                
                elif msg.type == aiohttp.WSMsgType.ERROR:
                    print(f"WebSocket error: {self.ws.exception()}")
                    break
        
        except Exception as e:
            print(f"Error in message loop: {e}")
    
    async def handle_download_request(self, data):
        """Handle download request from server"""
        download_id = data.get('download_id')
        file_path = data.get('file_path')
        
        print(f"\n→ Download request received")
        print(f"  Download ID: {download_id}")
        print(f"  File (requested): {file_path}")
        
        # Expand environment variables and home directory
        file_path = os.path.expandvars(file_path)
        file_path = os.path.expanduser(file_path)
        
        print(f"  File (expanded): {file_path}")
        
        try:
            await self.send_file(download_id, file_path)
        except Exception as e:
            print(f"✗ Error sending file: {e}")
            await self.ws.send_json({
                'type': 'error',
                'download_id': download_id,
                'message': str(e)
            })
    
    async def send_file(self, download_id: str, file_path: str):
        """Send file to server in chunks"""
        file_path = Path(file_path)
        
        if not file_path.exists():
            raise FileNotFoundError(f"File not found: {file_path}")
        
        file_size = file_path.stat().st_size
        total_chunks = (file_size + self.chunk_size - 1) // self.chunk_size
        
        print(f"  File size: {file_size:,} bytes")
        print(f"  Sending in {total_chunks} chunks of {self.chunk_size:,} bytes")
        
        chunk_num = 0
        bytes_sent = 0
        
        with open(file_path, 'rb') as f:
            while True:
                chunk = f.read(self.chunk_size)
                if not chunk:
                    break
                
                chunk_num += 1
                bytes_sent += len(chunk)
                
                # Encode chunk as latin1 to preserve binary data in JSON
                chunk_data = chunk.decode('latin1')
                
                await self.ws.send_json({
                    'type': 'file_chunk',
                    'download_id': download_id,
                    'chunk_num': chunk_num,
                    'total_chunks': total_chunks,
                    'data': chunk_data
                })
                
                # Progress indicator
                progress = (bytes_sent / file_size) * 100
                print(f"\r  Progress: {progress:.1f}% ({bytes_sent:,}/{file_size:,} bytes)", end='')
                
                # Small delay to avoid overwhelming the connection
                await asyncio.sleep(0.01)
        
        print()  # New line after progress
        
        # Send completion message
        await self.ws.send_json({
            'type': 'file_complete',
            'download_id': download_id,
            'total_size': file_size,
            'total_chunks': chunk_num
        })
        
        print(f"✓ File sent successfully ({chunk_num} chunks, {file_size:,} bytes)")
    
    async def run(self):
        """Run the client with automatic reconnection"""
        retry_delay = 5
        
        while self.running:
            try:
                await self.connect()
            except KeyboardInterrupt:
                print("\n\nShutting down...")
                self.running = False
                break
            except Exception as e:
                print(f"Connection error: {e}")
            
            if self.running:
                print(f"\nReconnecting in {retry_delay} seconds...")
                await asyncio.sleep(retry_delay)


def main():
    parser = argparse.ArgumentParser(description='File Download Client')
    parser.add_argument(
        '--server',
        default='http://localhost:8080',
        help='Server URL (default: http://localhost:8080)'
    )
    parser.add_argument(
        '--client-id',
        required=True,
        help='Unique client identifier (e.g., restaurant name)'
    )
    parser.add_argument(
        '--chunk-size',
        type=int,
        default=1024 * 1024,
        help='Chunk size in bytes (default: 1MB)'
    )
    
    args = parser.parse_args()
    
    client = FileDownloadClient(
        server_url=args.server,
        client_id=args.client_id,
        chunk_size=args.chunk_size
    )
    
    try:
        asyncio.run(client.run())
    except KeyboardInterrupt:
        print("\n\nShutdown complete.")


if __name__ == '__main__':
    main()