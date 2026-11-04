#!/usr/bin/env python3
"""Sends commands over Home Assistant's websocket API and prints the results as JSON.

    HA_URL=... HA_TOKEN=... ha-ws.py '[{"type": "energy/get_prefs"}, ...]'

Prints a JSON array with one result per command (null where a command failed). The
websocket API has what the REST API lacks: entity categories, the energy dashboard's
settings and long-term statistics. The token comes from the environment, as other users
can read a process's arguments. Standard library only.
"""
import base64
import json
import os
import socket
import ssl
import struct
import sys
from urllib.parse import urlparse


def connect(url):
    parts = urlparse(url)
    secure = parts.scheme == "https"
    port = parts.port or (443 if secure else 80)
    sock = socket.create_connection((parts.hostname, port), timeout=15)
    if secure:
        sock = ssl.create_default_context().wrap_socket(sock, server_hostname=parts.hostname)
    key = base64.b64encode(os.urandom(16)).decode()
    sock.sendall((
        f"GET /api/websocket HTTP/1.1\r\nHost: {parts.netloc}\r\nUpgrade: websocket\r\n"
        f"Connection: Upgrade\r\nSec-WebSocket-Key: {key}\r\nSec-WebSocket-Version: 13\r\n\r\n"
    ).encode())
    response = b""
    while b"\r\n\r\n" not in response:
        chunk = sock.recv(4096)
        if not chunk:
            raise ConnectionError("closed during handshake")
        response += chunk
    if b" 101 " not in response.split(b"\r\n")[0]:
        raise ConnectionError(response.split(b"\r\n")[0].decode())
    return sock, bytearray(response.split(b"\r\n\r\n", 1)[1])


def read_exact(sock, buffer, count):
    while len(buffer) < count:
        chunk = sock.recv(65536)
        if not chunk:
            raise ConnectionError("closed")
        buffer += chunk
    data = bytes(buffer[:count])
    del buffer[:count]
    return data


def receive(sock, buffer):
    message = b""
    while True:
        first, second = read_exact(sock, buffer, 2)
        length = second & 0x7F
        if length == 126:
            length = struct.unpack(">H", read_exact(sock, buffer, 2))[0]
        elif length == 127:
            length = struct.unpack(">Q", read_exact(sock, buffer, 8))[0]
        payload = read_exact(sock, buffer, length)
        opcode = first & 0x0F
        if opcode == 8:
            raise ConnectionError("closed by Home Assistant")
        if opcode in (0, 1, 2):
            message += payload
            if first & 0x80:
                return json.loads(message)


def send(sock, value):
    payload = json.dumps(value).encode()
    header = bytes([0x81])
    if len(payload) < 126:
        header += bytes([0x80 | len(payload)])
    elif len(payload) < 65536:
        header += bytes([0x80 | 126]) + struct.pack(">H", len(payload))
    else:
        header += bytes([0x80 | 127]) + struct.pack(">Q", len(payload))
    mask = os.urandom(4)
    sock.sendall(header + mask + bytes(b ^ mask[i % 4] for i, b in enumerate(payload)))


def main():
    url, token, commands = os.environ["HA_URL"], os.environ["HA_TOKEN"], json.loads(sys.argv[1])
    sock, buffer = connect(url)
    receive(sock, buffer)  # auth_required
    send(sock, {"type": "auth", "access_token": token})
    if receive(sock, buffer).get("type") != "auth_ok":
        raise PermissionError("Home Assistant refused the token")
    for number, command in enumerate(commands, 1):
        send(sock, dict(command, id=number))
    results = [None] * len(commands)
    waiting = len(commands)
    while waiting:
        reply = receive(sock, buffer)
        if reply.get("type") == "result":
            results[reply["id"] - 1] = reply.get("result") if reply.get("success") else None
            waiting -= 1
    sock.close()
    print(json.dumps(results))


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        print(json.dumps({"error": str(error)}))
        sys.exit(1)
