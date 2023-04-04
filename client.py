# Echo client program
import socket
import time
import random
import math

def decide_action(data):
    #logic for next move will come here
    return random_action()


def random_action():
    return math.floor(10 * random.random())


HOST = '127.0.0.1'  # The remote host
PORT = 8888          # The same port as used by the server
with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
    s.connect((HOST, PORT))
    #s.sendall(b'Hello, world') # NOTE: CAUSES ERROR/WARNING AS LUA SCRIPT TRIES TO USE AS A MOVE CHOICE
    while True:
        data = s.recv(1024)
        print('Received', repr(data))
        action = decide_action(data)
        s.sendall(bytes(str(action), 'utf-8'))
        time.sleep(1)
#     data = s.recv(1024)
# print('Received', repr(data))