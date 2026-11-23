#!/usr/bin/env python
"""Run uvicorn on one dual-stack socket ([::]:PORT with IPV6_V6ONLY=0), so the app answers on
Railway's IPv6 private network and on IPv4 alike. uvicorn's own --host :: is IPv6-only.
Usage: serve.py PORT APP [uvicorn args...]"""
import os, socket, sys

port, app, extra = int(sys.argv[1]), sys.argv[2], sys.argv[3:]
sock = socket.socket(socket.AF_INET6, socket.SOCK_STREAM)
sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
sock.setsockopt(socket.IPPROTO_IPV6, socket.IPV6_V6ONLY, 0)
sock.bind(("::", port))
sock.listen(2048)
sock.set_inheritable(True)
os.execvp("uvicorn", ["uvicorn", app, "--fd", str(sock.fileno()), *extra])
