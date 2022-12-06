# Echo client program
import socket
import time

HOST = '127.0.0.1'  # The remote host
PORT = 8888          # The same port as used by the server
with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
    s.connect((HOST, PORT))
    s.sendall(b'Hello, world')
    while True:
        data = s.recv(1024)
        print('Received', repr(data))
        time.sleep(1)
#     data = s.recv(1024)
# print('Received', repr(data))