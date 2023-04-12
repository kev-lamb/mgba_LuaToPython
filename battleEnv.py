import numpy as np
import gymnasium as gym
from gymnasium.spaces import Dict, Box, Discrete, Sequence, Tuple
import asyncio
from battleClient import performAction, resetState, emulator_connect

# subspaces of the observation space
move = Dict({
                "Acc" : Box(low=0, high=256, shape=(1,), dtype=np.int32), #party mon moves
                "BP" : Box(low=0, high=256, shape=(1,), dtype=np.int32),
                "Eff" : Box(low=0, high=256, shape=(1,), dtype=np.int32),
                "Type" : Discrete(18)
            })
    
enemymon = Dict({
            "Species" : Box(low=0, high=399, shape=(1,), dtype=np.int32), #individual enemy mon and all stats
            "T1" : Discrete(18),
            "T2" : Discrete(18),
            "HP" : Box(low=0, high=999, shape=(1,), dtype=np.int32),
            "MaxHP" : Box(low=0, high=999, shape=(1,), dtype=np.int32),
            "Atk" : Box(low=0, high=999, shape=(1,), dtype=np.int32),
            "Def" : Box(low=0, high=999, shape=(1,), dtype=np.int32),
            "SpA" : Box(low=0, high=999, shape=(1,), dtype=np.int32),
            "SpD" : Box(low=0, high=999, shape=(1,), dtype=np.int32),
            "Spe" : Box(low=0, high=999, shape=(1,), dtype=np.int32)
        })
    
partymon = Dict({
                "Species" : Box(low=0, high=399, shape=(1,), dtype=np.int32), #individual party mon and all stats
                "T1" : Discrete(18),
                "T2" : Discrete(18),
                "HP" : Box(low=0, high=999, shape=(1,), dtype=np.int32),
                "MaxHP" : Box(low=0, high=999, shape=(1,), dtype=np.int32),
                "Atk" : Box(low=0, high=999, shape=(1,), dtype=np.int32),
                "Def" : Box(low=0, high=999, shape=(1,), dtype=np.int32),
                "SpA" : Box(low=0, high=999, shape=(1,), dtype=np.int32),
                "SpD" : Box(low=0, high=999, shape=(1,), dtype=np.int32),
                "Spe" : Box(low=0, high=999, shape=(1,), dtype=np.int32),
                "Moves" : Tuple((move, move, move, move))
            }) 

# default reward function is the difference between the enemy's health subtracted by 1/2 the difference in your health
# TODO: add stuff about terminal cases, add logic regarding when pokemon faint
def basic_reward(obs, next_obs, done):
    delta_enemy = obs['Enemy']['HP'] - next_obs['Enemy']['HP']
    delta_party = obs['Party'][0]['HP'] - next_obs['Party'][0]['HP']

     #if battle is over and enemy pokemon has 0 hp, we won the battle and should reward heavily
    if done:
        if obs['Enemy']['HP'] == 0:
            # we won, reward heavy
            return obs['Enemy']['MaxHP'] * 10
        else:
            # we lost, punish heavy
            return -10 * obs['Party'][0]['MaxHP']


    return delta_enemy - (delta_party / 2)

# Class for Battle Agent Environment
class BattleEnv(gym.Env):
    async def __init__(self, reward_function = basic_reward, port = 8888):
        # Define your custom environment here
        # Observations are dicts the contain metadata about all party mons and the active enemy
        self.observation_space = Dict({
            "Party" : Tuple((partymon, partymon, partymon, partymon, partymon, partymon)),
            "Enemy" : enemymon
        })

        #can perform any of the 4 attacks (other networks might also include switching and this would change to 10)
        self.action_space = Box(low=0, high=1, shape=(4,))

        # configurable reward function
        self.reward_function = reward_function

        # TODO: define default observation
        self.observation = False

        # readers and writers for communicating with emulator at various points in time
        self.reader, self.writer = await emulator_connect(port) #takes optional port object
        

    async def reset(self, initial_state):
        # Reset the environment to its initial state and return the initial observation
        # based on the savestate, initial observation here would be different.
        # I probably don't want any async code in this class, so maybe i feed in the initial state as an arg here
        observation = await resetState(initial_state)
        self.observation = observation
        info = None #TODO: do i want anything here?
        return observation, info

    # must be async because we need to communicate with the emulator
    async def step(self, action):
        # Execute the given action and return the new observation, reward, done, and info
        next_state = await performAction(action)
        done = next_state['Mode'] == "Traversal"

        next_observation = None if done else next_state['Data']

        reward = self.reward_function(self.observation, next_observation, done)

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

