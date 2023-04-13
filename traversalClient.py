import math
import json
import asyncio

from traversalagent import traversal_agent_action
from battleClient import emulator_connect

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

    # send input action to the emulator for execution
    writer.write(bytes(json.dumps(action), 'utf-8'))

    # return resulting emulator state once action has been performed
    new_state = await reader.read(1024)
    return json.loads(new_state.decode("utf-8"))