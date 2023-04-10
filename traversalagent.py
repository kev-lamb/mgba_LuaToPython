#imports
import math
import random

#TODO: refactor the code s.t. this function takes a second arg "agent" which specifies which agent to use
# ex: random, Q-learning, ...
#main traversal agent

# for now, limit options to A, UP, DOWN, LEFT, RIGHT
def traversalagent(data):
    possible_actions = [0, 4, 5, 6, 7]
    #for now, do random agent
    decision = possible_actions[random_action()]
    action = [[decision, 10]]
    return action

def random_action():
    return math.floor(5 * random.random())

def update_traversal_rewards(data_loaded, visited_zoneIDs, visited_coords):

    mode = data_loaded["Mode"]

    if (mode == "Traversal"):
        
        cur_zoneID = data_loaded["Data"]["zone"]
        visited_zoneIDs.add(cur_zoneID)

        #print("visited zoneIDs: ", visited_zoneIDs, "\n")

        cur_x = data_loaded["Data"]["x"]
        cur_y = data_loaded["Data"]["y"]

        coords_in_zoneID = visited_coords.get(cur_zoneID)

        if coords_in_zoneID is None:
            visited_coords[cur_zoneID] = set()

        visited_coords[cur_zoneID].add((cur_x, cur_y))

        #print("visited coords: ", visited_coords, "\n")

    # calculate points based on size of visited_zoneIDs
    zoneID_points = 20 * len(visited_zoneIDs)

    #print("zoneID points: ", zoneID_points, "\n")

    # calculate points based on total size of all values in visited coords
    coords_points = 0
    for zoneID in visited_coords:
        coords_in_zone = len(visited_coords[zoneID])
        coords_points += coords_in_zone

    #print("coords points: ", coords_points, "\n")
    
    return zoneID_points + coords_points
