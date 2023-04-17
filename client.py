# Echo client program
import socket
import os
import time
import random
import math
import json
import asyncio
from battleagent import battleagent
from traversalagent import traversal_agent_choose_action, update_traversal_rewards, dummy_traversal_policy
from battleEnv import BattleEnv
from generalEnv import GeneralEnv
import torch
import torch.nn.functional as F
import numpy as np
import gymnasium as gym
from gymnasium.spaces.utils import flatdim, flatten
from battleDQN import DQN
from policyFxns import epsilon_greedy, epsilon_greedy_decay

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
            data = await reader.read(4096)
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
        return traversal_agent_choose_action(data["Traversal"])

    #if not in traversal mode, we are in battle mode

    #if we just entered battle mode, we should press A to get through the pre-battle text
    if last_mode == "Traversal":
        last_mode = "Battle"
        return [[0, 500], [1, 500], [0, 500], 1]

    global last_action
    action, last_action = battleagent(data["Battle"], 0)
    return action

def random_action():
    return math.floor(10 * random.random())

async def agent(battle_model_file="dirtybattlemodel.pt", traversal_model_file=""):
    # create environment object abstraction of emulator
    general_env = GeneralEnv()
    battle_env = BattleEnv()

    # establishes socket connection
    await general_env._init()

    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")

    n_actions = battle_env.action_space.shape[0]
    n_observations = flatdim(battle_env.observation_space)

    battle_model = DQN(n_observations, n_actions).to(device)

    if os.path.isfile(os.path.join(os.getcwd(), battle_model_file)):
        battle_model.load_state_dict(torch.load(battle_model_file))

    # for demo, always take the recommended action
    epsilon = 1.0
    battle_policy = epsilon_greedy(n_actions, epsilon, device)

    # reset game state to demo state
    state, info = await general_env.reset("/demoStates")
    done = False
    
    # action loop
    while(True):
        battlestate = torch.tensor(flatten(battle_env.observation_space, state['Battle']), dtype=torch.float32).unsqueeze(0)

        action = []
        if done:
            # we just switched modes, do a few A and B inputs to flush out unwanted text
            action = [[0, 500], [1, 500], [0, 500], 1]

        elif state['Mode'] == 'Traversal':
            #traversal agent takes control
            action = dummy_traversal_policy(state['Traversal'])

        else:
            #battle agent takes control
            with torch.no_grad():
                action = battle_policy(battle_model, battlestate, 0)


        # perform action on the emulator
        state, reward, done, info = await general_env.step(action, None if done else state['Mode'])



if __name__ == "__main__":
    # asyncio.run(websocket_client())
    asyncio.run(agent())


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