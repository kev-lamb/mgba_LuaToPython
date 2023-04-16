import os
import random
import numpy as np
import gymnasium as gym
from gymnasium.spaces import Dict, Box, Discrete, Sequence, Tuple
import asyncio
from battleClient import performAction, resetState, emulator_connect, getState

# subspaces of the observation space
move = Dict({
                "acc" : Box(low=0, high=256, shape=(1,), dtype=np.int32), #party mon moves
                "bp" : Box(low=0, high=256, shape=(1,), dtype=np.int32),
                "eff" : Box(low=0, high=256, shape=(1,), dtype=np.int32),
                "type" : Discrete(18)
            })
    
enemymon = Dict({
            "species" : Box(low=0, high=399, shape=(1,), dtype=np.int32), #individual enemy mon and all stats
            "t1" : Discrete(18),
            "t2" : Discrete(18),
            "hp" : Box(low=0, high=999, shape=(1,), dtype=np.int32),
            "maxHP" : Box(low=0, high=999, shape=(1,), dtype=np.int32),
            "atk" : Box(low=0, high=999, shape=(1,), dtype=np.int32),
            "def" : Box(low=0, high=999, shape=(1,), dtype=np.int32),
            "spa" : Box(low=0, high=999, shape=(1,), dtype=np.int32),
            "spd" : Box(low=0, high=999, shape=(1,), dtype=np.int32),
            "spe" : Box(low=0, high=999, shape=(1,), dtype=np.int32)
        })
    
partymon = Dict({
                "species" : Box(low=0, high=399, shape=(1,), dtype=np.int32), #individual party mon and all stats
                "t1" : Discrete(18),
                "t2" : Discrete(18),
                "hp" : Box(low=0, high=999, shape=(1,), dtype=np.int32),
                "maxHP" : Box(low=0, high=999, shape=(1,), dtype=np.int32),
                "atk" : Box(low=0, high=999, shape=(1,), dtype=np.int32),
                "def" : Box(low=0, high=999, shape=(1,), dtype=np.int32),
                "spa" : Box(low=0, high=999, shape=(1,), dtype=np.int32),
                "spd" : Box(low=0, high=999, shape=(1,), dtype=np.int32),
                "spe" : Box(low=0, high=999, shape=(1,), dtype=np.int32),
                "moves" : Tuple((move, move, move, move))
            }) 

# default reward function is the difference between the enemy's health subtracted by 1/2 the difference in your health
# TODO: add stuff about terminal cases, add logic regarding when pokemon faint
def basic_reward(obs, next_obs, done):
    # print(obs)
    # print(next_obs)
    delta_enemy = obs['Enemy']['hp'] - next_obs['Enemy']['hp']
    delta_party = obs['Party'][0]['hp'] - next_obs['Party'][0]['hp']

     #if battle is over and enemy pokemon has 0 hp, we won the battle and should reward heavily
    if done:
        if obs['Enemy']['hp'] == 0:
            # we won, reward heavy
            return obs['Enemy']['maxHP'] * 10
        else:
            # we lost, punish heavy
            return -10 * obs['Party'][0]['maxHP']


    return delta_enemy - (delta_party / 2)

# Class for Battle Agent Environment
class BattleEnv(gym.Env):
    def __init__(self, reward_function = basic_reward, port = 8888):
        # Define your custom environment here
        # Observations are dicts the contain metadata about all party mons and the active enemy
        self.observation_space = Dict({
            "Enemy" : enemymon,
            "Party" : Tuple((partymon, partymon, partymon, partymon, partymon, partymon))
        })

        #can perform any of the 4 attacks (other networks might also include switching and this would change to 10)
        self.action_space = Box(low=0, high=1, shape=(4,))

        # configurable reward function
        self.reward_function = reward_function

        # TODO: define default observation
        self.observation = False

        # readers and writers for communicating with emulator at various points in time
        # self.reader, self.writer = loop.run_until_complete(emulator_connect(port)) #takes optional port object

    async def _init(self, port = 8888):
        self.reader, self.writer = await emulator_connect(port)
        self.observation = await getState(self.reader, self.writer)
        

    async def reset(self, initial_state_folder):
        # Reset the environment to its initial state and return the initial observation
        # based on the savestate, initial observation here would be different.
        # get filepath to a random training save state
        initial_state = initial_state_folder + "/" + random.choice(os.listdir(os.getcwd() + initial_state_folder))

        observation = await resetState(initial_state, self.reader, self.writer)
        self.observation = observation['Battle']
        info = None #TODO: do i want anything here?
        return observation['Battle'], info

    # must be async because we need to communicate with the emulator
    async def step(self, action):
        # Execute the given action and return the new observation, reward, done, and info
        next_state = await performAction(action, self.reader, self.writer)
        done = next_state['Mode'] == "Traversal"

        next_observation = None if done else next_state['Battle']
        # TODO: observation needs to be cleaned so its the same format as the observation space

        # passing in next_state['Battle'] instead of next observation so we can figure out if battle was won or lost if its over
        reward = self.reward_function(self.observation, next_state['Battle'], done)

        info = {} # add debugging info here if needed
        info['Mode'] = next_state['Mode']

        self.observation = next_observation
        return next_observation, reward, done, info

    def render(self, mode='human'):
        # Render the current state of the environment
        # I dont think i need anything here, im not really rendering through this
        return

# env = BattleEnv()

# # Example usage of the environment
# observation = env.reset()
# for t in range(100):
#     action = env.action_space.sample()
#     observation, reward, done, info = env.step(action)
#     if done:
#         print("Episode finished after {} timesteps".format(t+1))
#         break
#     env.render()

# # You can then use this environment with PyTorch by wrapping it in a gym wrapper
# import gym.wrappers
# env = gym.wrappers.TimeLimit(env, max_episode_steps=1000) # limit the number of steps per episode

