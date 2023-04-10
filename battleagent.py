#imports
import math
import random


#TODO: refactor the code s.t. this function takes a second arg "agent" which specifies which agent to use
# ex: random, Q-learning, ...
#main battle agent

# battle actions are abstracted from button presses to [attack1, attack2, attack3, attack4] (will add switch if time permitting)
# button presses requried for each action changes depending on what the last attack was
def battleagent(data, last_action):
    animation_delay = 800 #frames needed for attack animations to play out and user to get prompted for next attack
    potential_actions = []
    s = [0, [0, animation_delay], 1]
    r = [0, 4, [0, animation_delay], 1]
    l = [0, 5, [0, animation_delay], 1]
    u = [0, 6, [0, animation_delay], 1]
    d = [0, 7, [0, animation_delay], 1]
    rd = [0, 4, 7, [0, animation_delay], 1]
    ld = [0, 5, 7, [0, animation_delay], 1]
    ru = [0, 4, 6, [0, animation_delay], 1]
    lu = [0, 5, 6, [0, animation_delay], 1]

    if last_action == 0:
        potential_actions = [s, r, d, rd]
    elif last_action == 1:
        potential_actions = [l, s, ld, d]
    elif last_action == 2:
        potential_actions = [u, ru, s, r]
    elif last_action == 3:
        potential_actions = [lu, u, l, s]

    decision = random_action()
    action = potential_actions[decision]
    return action, decision

def random_action():
    return math.floor(4 * random.random())