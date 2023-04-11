import math
import json
import asyncio

# Client meant exclusively for battling. Used for training the battle agent

async def resetState(initialState, port = 8888):
    reader, writer = await emulator_connect(port)

    reset_msg = {}
    reset_msg['Reset'] = initialState # should be a filepath to a save state

    writer.write(bytes(json.dumps(reset_msg), 'utf-8'))

    new_state = await reader.read(1024)
    return json.loads(new_state.decode("utf-8"))


async def performAction(action, port = 8888):
    # establish connection with emulator
    reader, writer = await emulator_connect(port)

    # convert provided action into appropriate emulator actions (maybe this should be done by the emulator long term?)
    action = emulator_action(action)

    # send input action to the emulator for execution
    writer.write(bytes(json.dumps(action), 'utf-8'))

    # return resulting emulator state once action has been performed
    new_state = await reader.read(1024)
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

def emulator_action(action):
    animation_delay = 800
    move1 = [0, 5, 6, [0, animation_delay], 1]
    move2 = [0, 5, 6, 4, [0, animation_delay], 1]
    move3 = [0, 5, 6, 7, [0, animation_delay], 1]
    move4 = [0, 5, 6, 4, 7, [0, animation_delay], 1]
    potential_actions = [move1, move2, move3, move4]
    return potential_actions[action]