import gymnasium as gym
from gymnasium.spaces import Dict, Box, Discrete, Sequence, Tuple
from gymnasium.spaces.utils import flatdim
import numpy as np
import os, random

move = Dict({
                "Acc" : Box(low=0, high=256, shape=(1,), dtype=np.int32), #party mon moves
                "BP" : Box(low=0, high=256, shape=(1,), dtype=np.int32),
                "Eff" : Box(low=0, high=256, shape=(1,), dtype=np.int32),
                "Type" : Discrete(18)
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


space = Dict({
            "Party" : Tuple((partymon, partymon, partymon, partymon, partymon, partymon)),
            "Enemy" : Dict({
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
        })

dir = os.getcwd()

print(os.listdir(dir + "/trainStates"))

print(random.choice(os.listdir()))