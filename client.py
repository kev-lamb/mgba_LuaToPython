# Echo client program
import socket
import time
import random
import math
import json
import asyncio
from battleagent import battleagent
from traversalagent import traversal_agent_choose_action, update_traversal_rewards

last_action = 0
#encode special actions when switching modes
last_mode = "Traversal"
visited_zoneIDs = set()
visited_coords = {}

async def handle_message(message):
    global visited_zoneIDs
    global visited_coords
    """Function to handle incoming messages"""
    try:
        data = json.loads(message)
        print(f"Received message: {data}")
        # Points = (20 * # of zones visited) + (# of unique coordinates visited)
        traversal_rewards = update_traversal_rewards(data, visited_zoneIDs, visited_coords)
        # Do something with the message data here
        action = decide_action(data)
        return action
    except Exception as e:
        print(f"Error processing message: {message}\nError: {e}")


async def websocket_client():
    """Coroutine to create a WebSocket client"""
    try:
        uri = '127.0.0.1'
        port = 8888
        reader, writer = await asyncio.open_connection(uri, port)
        print(f"Connected to WebSocket server at {uri}:{port}")
        while True:
            data = await reader.read(1024)
            if not data:
                break
            action = await handle_message(data.decode("utf-8"))
            writer.write(bytes(json.dumps(action), 'utf-8'))
    except ConnectionRefusedError:
        print("WebSocket connection refused, retrying in 5 seconds...")
        await asyncio.sleep(5)
        await websocket_client()

def decide_action(data):
    #logic for next move will come here
    global last_mode
    mode = data["Mode"]
    print(mode)
    print(last_mode)
    if mode == "Traversal":
        last_mode = "Traversal"
        return traversalagent(data["Data"])

    #if not in traversal mode, we are in battle mode

    #if we just entered battle mode, we should press A to get through the pre-battle text
    if last_mode == "Traversal":
        last_mode = "Battle"
        return [[0, 500], [1, 500], [0, 500], 1]

    global last_action
    action, last_action = battleagent(data["Data"], last_action)
    return action

def random_action():
    return math.floor(10 * random.random())

if __name__ == "__main__":
    asyncio.run(websocket_client())


# HOST = '127.0.0.1'  # The remote host
# PORT = 8888          # The same port as used by the server
# with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
#     s.connect((HOST, PORT))
#     #s.sendall(b'Hello, world') # NOTE: CAUSES ERROR/WARNING AS LUA SCRIPT TRIES TO USE AS A MOVE CHOICE
#     while True:
#         data = s.recv(1024)
#         # print("yuh")
#         print('Received', repr(data))
#         info = json.loads(data)
#         action = decide_action(info)
#         s.sendall(bytes(json.dumps(action), 'utf-8'))
#         time.sleep(1)
#     data = s.recv(1024)
# print('Received', repr(data))