#imports
import os
import math
import random
from battleDQN import DQN
from battleEnv import BattleEnv
import torch
import torch.nn.functional as F
import numpy as np
import gymnasium as gym
from gymnasium.spaces.utils import flatdim, flatten
from battleTrain import BattleAgent, ReplayMemory
from policyFxns import epsilon_greedy, epsilon_greedy_decay


#TODO: refactor the code s.t. this function takes a second arg "agent" which specifies which agent to use
# ex: random, Q-learning, ...
#main battle agent

# battle actions are abstracted from button presses to [attack1, attack2, attack3, attack4] (will add switch if time permitting)
# button presses requried for each action changes depending on what the last attack was
def battleagent(data, last_action, agent="random"):
    animation_delay = 800 #frames needed for attack animations to play out and user to get prompted for next attack
    potential_actions = []
    s = [0, 5, 6, [0, animation_delay], 1, 6, 1, 6, 1, 6, [1, 500]]
    r = [0, 5, 6, 4, [0, animation_delay], 1, 6, 1, 6, 1, 6, [1, 500]]
    l = [0, 5, 6, 5, [0, animation_delay], 1, 6, 1, 6, 1, 6, [1, 500]]
    u = [0, 5, 6, 6, [0, animation_delay], 1, 6, 1, 6, 1, 6, [1, 500]]
    d = [0, 5, 6, 7, [0, animation_delay], 1, 6, 1, 6, 1, 6, [1, 500]]
    rd = [0, 5, 6, 4, 7, [0, animation_delay], 1, 6, 1, 6, 1, 6, [1, 500]]
    ld = [0, 5, 6, 5, 7, [0, animation_delay], 1, 6, 1, 6, 1, 6, [1, 500]]
    ru = [0, 5, 6, 4, 6, [0, animation_delay], 1, 6, 1, 6, 1, 6, [1, 500]]
    lu = [0, 5, 6, [0, animation_delay], 1, 6, 1, 6, 1, 6, [1, 500]]

    if last_action == 0:
        potential_actions = [s, r, d, rd]
    elif last_action == 1:
        potential_actions = [l, s, ld, d]
    elif last_action == 2:
        potential_actions = [u, ru, s, r]
    elif last_action == 3:
        potential_actions = [lu, u, l, s]

    if agent == "random":
        decision = random_action()
        action = potential_actions[decision]
        return action, decision

    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    env = BattleEnv()
    n_actions = env.action_space.shape[0]

    #calculate the observation space so we can use it as input dim for our DQN
    #for now, only using naive input network that takes only first party mon. 
    #if we add switching capabilities, will have to change this
    n_observations = flatdim(env.observation_space)

    model = DQN(n_observations, n_actions).to(device)
    target_net = DQN(n_observations, n_actions).to(device)

    # if filepath provided, attempt to load the model at that filepath
    if os.path.isfile(os.path.join(os.getcwd(), agent)):
        model.load_state_dict(torch.load(agent))

    # for demo, always take the recommended action
    epsilon = 1.0
    policy = epsilon_greedy(n_actions, epsilon, device)
    state = torch.tensor(flatten(env.observation_space, data), dtype=torch.float32).unsqueeze(0)
    with torch.no_grad():
        action = policy(model, state, 0)


    decision = random_action()
    action = potential_actions[decision]
    return action, decision

def random_action():
    return math.floor(4 * random.random())