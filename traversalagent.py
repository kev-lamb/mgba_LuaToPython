#imports
import math
import random

#TODO: refactor the code s.t. this function takes a second arg "agent" which specifies which agent to use
# ex: random, Q-learning, ...
#main traversal agent
def traversalagent(data):
    #for now, do random agent
    decision = random_action()
    return decision

def random_action():
    return math.floor(10 * random.random())