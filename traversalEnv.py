import numpy as np
import gymnasium as gym
from gymnasium.spaces import Dict, Discrete
import asyncio
from traversalClient import performAction, resetState

# Class for Traversal Agent Environment
class TraversalEnv(gym.Env):

    # default reward function is 1 (if the cur coord is new) + 20 (if the cur coord is in a new zone)
    def basic_reward(obs, visited_zoneIDs, visited_coords):

        new_zoneID = 0 # Assumme we aren't in a new zone

        # If the current zone is not in the set of visited zones, it's a new zone
        if obs['zone'] not in visited_zoneIDs:
            new_zoneID = 1
            visited_zoneIDs.add(obs['zone']) # Add this zone since it's new
            visited_coords[obs['zone']] = set() # Give this new zone a (currently) empty entry in the visited coords dict

        new_coord = 0 # Assume we aren't at a new coordinate

        # If the current coord is not within the set of visited coords for the current zone, it's a new coordinate
        if (obs['x'], obs['y']) not in visited_coords[obs['zone']]:
            new_coord = 1
            visited_coords[obs['zone']].add((obs['x'], obs['y'])) # Add this coord since it's new

        return new_coord + (20 * new_zoneID)

    def __init__(self, reward_function = basic_reward):
        # Define your custom environment here
        # Observations are dicts the contain metadata about location data
        self.observation_space = Dict({
            "zone" : Discrete(999),
            "x" : Discrete(999),
            "y" : Discrete(999)
        })

        self.action_space = Discrete(5) # can move in any of the four directions or press A

        # configurable reward function
        self.reward_function = reward_function

        # TODO: define default observation
        self.observation = False

        self.visited_zoneIDs = set()
        self.visited_coords = {}
        
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
        done = next_state['Mode'] == "Battle"

        next_observation = self.observation if done else next_state['Traversal']
        self.observation = next_observation

        reward = self.reward_function(self.observation, self.visited_zoneIDs, self.visited_coords)

        info = {} # add debugging info here if needed
        info['Mode'] = next_state['Mode']

        return next_observation, reward, done, info

    def render(self, mode='human'):
        # Render the current state of the environment
        # I dont think i need anything here, im not really rendering through this
        return

# env = TraversaleEnv()

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