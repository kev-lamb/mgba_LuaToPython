import math
import json
import asyncio

# Client meant exclusively for battling. Used for training the battle agent

async def resetState(initialState, reader, writer):
    # tell emulator to load the save state at filepath initialState
    reset_msg = ['reset', initialState]

    writer.write(bytes(json.dumps(reset_msg), 'utf-8'))

    new_state = await reader.read(4096)
    return json.loads(new_state.decode("utf-8"))

async def getState(reader, writer):
    req = ['battle']

    writer.write(bytes(json.dumps(req), 'utf-8'))

    state = await reader.read(4096)
    return json.loads(state.decode("utf-8"))

async def performGeneralAction(action, mode, reader, writer):
    # format the action appropriately based on the mode
    if mode == 'Battle':
        action = battle_action(action)
    elif mode == 'Traversal':
        action = traversal_action(action)
    
    # perform the action (if performing a flush action, no formatting occurs)
    return await basicAction(action, reader, writer)


async def performBattleAction(action, reader, writer):
    # convert provided action into appropriate emulator actions (maybe this should be done by the emulator long term?)
    return await basicAction(battle_action(action), reader, writer)
    # action = battle_action(action)

    # # send input action to the emulator for execution
    # writer.write(bytes(json.dumps(action), 'utf-8'))

    # # return resulting emulator state once action has been performed
    # new_state = await reader.read(4096)
    # return json.loads(new_state.decode("utf-8"))


async def performTraversalAction(action, reader, writer):
    return await basicAction(traversal_action(action), reader, writer)
    # action = traversal_action(action)

    # # send input action to the emulator for execution
    # writer.write(bytes(json.dumps(action), 'utf-8'))

    # # return resulting emulator state once action has been performed
    # new_state = await reader.read(4096)
    # return json.loads(new_state.decode("utf-8"))

async def basicAction(action, reader, writer):
    # send input action to the emulator for execution
    writer.write(bytes(json.dumps(action), 'utf-8'))

    # return resulting emulator state once action has been performed
    new_state = await reader.read(4096)
    return json.loads(new_state.decode("utf-8"))


async def emulator_connect(port = 8888):
    """Coroutine to create a WebSocket client"""
    try:
        #todo: maybe the port could be an input to allow parallel training over different ports?
        uri = '127.0.0.1'
        port = port
        reader, writer = await asyncio.open_connection(uri, port)
        print(f"Connected to WebSocket server at {uri}:{port}")
        return reader, writer
        # while True:
        #     data = await reader.read(1024)
        #     if not data:
        #         break
        #     action = await handle_message(data.decode("utf-8"))
        #     writer.write(bytes(json.dumps(action), 'utf-8'))
    except ConnectionRefusedError:
        print("WebSocket connection refused, retrying in 5 seconds...")
        await asyncio.sleep(5)
        await emulator_connect(port)



#helper functions

def battle_action(action):
    animation_delay = 800
    move1 = [0, 5, 6, [0, animation_delay], 1]
    move2 = [0, 5, 6, 4, [0, animation_delay], 1]
    move3 = [0, 5, 6, 7, [0, animation_delay], 1]
    move4 = [0, 5, 6, 4, 7, [0, animation_delay], 1]
    potential_actions = [move1, move2, move3, move4]
    return potential_actions[action]

def traversal_action(action):
    possible_actions = [0, 4, 5, 6, 7]
    #for now, do random agent
    decision = possible_actions[action]
    return [[decision, 10]]