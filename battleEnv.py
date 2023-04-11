import numpy as np
import gymnasium as gym
from gymnasium.spaces import Dict, Box, Discrete, Sequence, MultiDiscrete
import asyncio
from battleClient import performAction, resetState

# Class for Battle Agent Environment
class BattleEnv(gym.Env):

    # default reward function is the difference between the enemy's health subtracted by 1/2 the difference in your health
    # TODO: add stuff about terminal cases, add logic regarding when pokemon faint
    def basic_reward(obs, next_obs):
        delta_enemy = obs['Enemy']['HP'] - next_obs['Enemy']['HP']
        delta_party = obs['Party'][0]['HP'] - next_obs['Party'][0]['HP']

        return delta_enemy - (delta_party / 2)
    

    def __init__(self, reward_function = basic_reward):
        # Define your custom environment here
        # Observations are dicts the contain metadata about all party mons and the active enemy
        self.observation_space = Dict({
            "Party" : Sequence(
                Dict({
                    "Species" : Discrete(400), #individual party mon and all stats
                    "T1" : Discrete(18),
                    "T2" : Discrete(18),
                    "HP" : Discrete(999),
                    "MaxHP" : Discrete(999),
                    "Atk" : Discrete(999),
                    "Def" : Discrete(999),
                    "SpA" : Discrete(999),
                    "SpD" : Discrete(999),
                    "Spe" : Discrete(999),
                    "Moves" : Sequence(Dict({
                        "Acc" : Discrete(101), #party mon moves
                        "BP" : Discrete(250),
                        "Eff" : Discrete(999),
                        "Type" : Discrete(18)
                    }))
                })    
            ),
            "Enemy" : Dict({
                "Species" : Discrete(400), #individual enemy mon and all stats
                "T1" : Discrete(18),
                "T2" : Discrete(18),
                "HP" : Discrete(999),
                "MaxHP" : Discrete(999),
                "Atk" : Discrete(999),
                "Def" : Discrete(999),
                "SpA" : Discrete(999),
                "SpD" : Discrete(999),
                "Spe" : Discrete(999)
            })
        })
        self.action_space = Discrete(4) #can perform any of the 4 attacks (other networks might also include switching and this would change to 10)

        # configurable reward function
        self.reward_function = reward_function

        # TODO: define default observation
        self.observation = False
        

    async def reset(self, initial_state):
        # Reset the environment to its initial state and return the initial observation
        # based on the savestate, initial observation here would be different.
        # I probably don't want any async code in this class, so maybe i feed in the initial state as an arg here
        observation = await resetState(initial_state)
        self.observation = observation
        return observation

    # must be async because we need to communicate with the emulator
    async def step(self, action):
        # Execute the given action and return the new observation, reward, done, and info
        next_state = await performAction(action)
        done = next_state['Mode'] == "Traversal"

        next_observation = self.observation if done else next_state['Data']

        reward = self.reward_function(self.observation, next_observation)

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

