#imports
import math
import random


#TODO: refactor the code s.t. this function takes a second arg "agent" which specifies which agent to use
# ex: random, Q-learning, ...
#main battle agent
def battleagent(data):
    decision = random_action()
    return decision

def random_action():
    return math.floor(10 * random.random())