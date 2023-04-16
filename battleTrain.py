# run to train the battle agent
import os
import argparse
from collections import namedtuple, deque
import random
import math
import torch
import json
import torch.nn.functional as F
import numpy as np
import gymnasium as gym
from gymnasium.spaces.utils import flatdim, flatten
from battleEnv import BattleEnv
from battleDQN import DQN
import asyncio

#HYPERPARAMTERS
n_steps = 50 #setting this wayyy low for now to make sure everything works before actually trying to train
gamma = 0.7 #discount factor for future rewards (i feel like this should be pretty low)
epsilon = 0.1 # defines how often we perform a random action during training rather than the optimal action for static epsilon greedy
# decaying epsilon greedy vars
epsilon_start = 0.9 #initial epsilon
epsilon_end = 0.2 #final epsilon once fully decayed
epsilon_decay = 100 # the higher this is, the slower epsilon decays

tau = 1e-2  # how slowly we update the target network 
#an argument could be made to keep it around this size tho so batches arent coming from too many different battles?
memory_capacity = 100 #maybe need to bump up big time when doing actual training 
# batch size may be too big for if/when memory capacity increases
batch_size = math.ceil(memory_capacity * 0.1) # how many transitions to sample from memory during each training epoch


Transition = namedtuple('Transition',
                        ('state', 'action', 'next_state', 'reward'))

# used for batch sampling during training
class ReplayMemory(object):

    def __init__(self, capacity):
        self.memory = deque([], maxlen=capacity)

    def push(self, *args):
        """Save a transition"""
        self.memory.append(Transition(*args))

    def sample(self, batch_size):
        return random.sample(self.memory, batch_size)

    def __len__(self):
        return len(self.memory)


# epsilon greedy policy function. Takes the max. estimated Q action some % of the time, otherwise takes a random action
def epsilon_greedy(n_actions, epsilon, device):
  def policy_fn(q_net, state, step=0):
    if torch.rand(1) < epsilon:
      return torch.randint(n_actions, size=(1,), device=device)
    else:
      with torch.no_grad():
        q_pred = q_net(state)
        return torch.argmax(q_pred).view(1,)
  return policy_fn


# decaying epsilon policy function. Early in training, we take a lot of random actions and take fewer random actions as training goes on
def epsilon_greedy_decay(n_actions, epsilon_start, epsilon_end, epsilon_decay, device):
  def policy_fn(q_net, state, step=0):
    eps = epsilon_end + (epsilon_start - epsilon_end) * math.exp(-1. * step / epsilon_decay)
    if torch.rand(1) < eps:
      return torch.randint(n_actions, size=(1,1), device=device)
    else:
      with torch.no_grad():
        q_pred = q_net(state)
        return torch.argmax(q_pred).view(1,1)
  return policy_fn

# soft update function for target network
def soft_update_from_to(source, target, tau):
  for target_param, param in zip(target.parameters(), source.parameters()):
    target_param.data.copy_(
      target_param.data * (1.0 - tau) + param.data * tau
  )

class BattleAgent():
    def __init__(self, policy, q_net, target_net, optimizer, tau, replay_buffer,
               batch_size):
        self.policy = policy
        self.q_net = q_net
        self.target_net = target_net
        # we never need to compute gradients on the target network, so we disable
        # autograd to speed up performance
        for p in self.target_net.parameters():
            p.requires_grad = False
        self.optimizer = optimizer
        self.tau = tau
        self.memory = replay_buffer
        self.batch_size = batch_size
        # we will start training right away (using epsilon decay policy helps with being able to start training immediately)
        # self.train_start = train_start
        # self.is_waiting = True
    
    def act(self, state, step):
        # we never need to compute gradients on action selection, so we disable
        # autograd to speed up performance
        with torch.no_grad():
            # commented code add potential for first n actions to be random rather than using the model
            # for this usecase I dont think we need this
            # if self.is_waiting:
            #     return torch.randint(6, (1,1))
            # input state has already been flattened for model ingestion
            return self.policy(self.q_net, state, step)
    
    def train(self, state, action, reward, discount, next_state, frame):
        # Add the step to our replay buffer
        self.memory.push(state, action, next_state, reward)  
        # Don't train if we dont have a full batch in memory
        if len(self.memory) < self.batch_size:
           return

        # Using the Replay Buffer, sample a batch of steps for training
        transitions = self.memory.sample(self.batch_size)

        # transpose the batch object so we can call individual attributes
        batch = Transition(*zip(*transitions))

        non_final_mask = torch.tensor(tuple(map(lambda s: s is not None,
                                          batch.next_state)), dtype=torch.bool)
        non_final_next_states = torch.cat([s for s in batch.next_state
                                                if s is not None])

        state_batch = torch.cat(batch.state)
        action_batch = torch.cat(batch.action)
        reward_batch = torch.cat(batch.reward)

        # First let's compute our predicted q-values
        # We need to pass our batch of states (batch.state) to our q_net
        # print(batch.state)    
        q_actions = self.q_net(state_batch)
        # Then we select the q-values that correspond to the actions in our batch
        # (batch.action) to get our predictions (hint: use the gather method)
        q_pred = q_actions.gather(1, action_batch)
        
        # Now compute the q-value target (also known as the td target or bellman
        # backup) using our target network. Since we don't need gradients for this,
        # we disable autograd here to speed up performance    
        with torch.no_grad():
            # First get the q-values from our target_net using the batch of next
            # states.
            q_target_actions = torch.zeros(self.batch_size)
            q_target_actions[non_final_mask] = self.target_net(non_final_next_states).max(1)[0]
            # Get the values that correspond to the best action by taking the max along
            # the value dimension (dim=1)
            # q_target = q_target_actions.max(dim=1)[0].view(-1, 1)
            # Next multiply q_target by batch.discount and add batch.reward
            q_target = reward_batch + discount * q_target_actions
        # Compute the MSE loss between the predicted and target values, then average
        # over the batch
        loss = F.mse_loss(q_pred, q_target.unsqueeze(1))/self.batch_size #another loss to try is Huber loss according to pytorch guide

        # backpropogation to update the q-network
        self.optimizer.zero_grad()
        loss.backward()
        self.optimizer.step()

        # soft update target network with the updated q-network
        soft_update_from_to(self.q_net, self.target_net, self.tau)


# setup environment and device driver
async def setup(reward_function, filepath, new):
    # takes an optional reward function argument

    # don't let user train new model if model already exists at filepath
    if new and filepath is not None:
        if os.path.exists(filepath):
            print("Attempted to train a new model but model already exists at this filepath")

    env = BattleEnv() if reward_function is None else BattleEnv(reward_function=reward_function)
    await env._init()

    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")

    n_actions = env.action_space.shape[0]

    #calculate the observation space so we can use it as input dim for our DQN
    #for now, only using naive input network that takes only first party mon. 
    #if we add switching capabilities, will have to change this
    n_observations = flatdim(env.observation_space)
    print(n_observations)


    q_net = DQN(n_observations, n_actions).to(device)
    target_net = DQN(n_observations, n_actions).to(device)

    # if filepath provided, attempt to load the model at that filepath
    if not new and filepath is not None:
        q_net.load_state_dict(torch.load(filepath))
        target_net.load_state_dict(torch.load(filepath))

    # create agent for testing/training
    policy = epsilon_greedy_decay(n_actions, epsilon_start, epsilon_end, epsilon_decay, device)
    optimizer = torch.optim.Adam(q_net.parameters(), lr=1e-3) # maybe change to adamW if not working well
    memory = ReplayMemory(memory_capacity)
    agent = BattleAgent(policy, q_net, target_net, optimizer, tau, memory, batch_size)

    #returning q_net as well as agent because we want agent for training, q_net for testing
    return env, device, agent, q_net


# TODO: implement
# MAIN TRAINING LOOP
async def train(env, agent, gamma, n_steps, state_folder, filename):
    # MAIN TRAINING LOOP
    state, info = await env.reset(state_folder)
    state = torch.tensor(flatten(env.observation_space, state), dtype=torch.float32).unsqueeze(0)

    ep_reward = []
    ep_steps = []
    reward = 0
    t = 0

    # unneeded
    # tic = time.time()

    # each action is a new turn of a battle
    for turn in range(n_steps):
        # ask agent for an action in the given state
        #print(json.dumps(state))
        #flat_state = torch.tensor(flatten(env.observation_space, state), dtype=torch.float32)
        act = agent.act(state, turn)
        # execute the given action on the emulator
        next_state, rew, done, info = await env.step(act)
        next_state = torch.tensor(flatten(env.observation_space, next_state), dtype=torch.float32).unsqueeze(0) if next_state is not None else None
        rew = torch.tensor([rew])
    
        agent.train(state, act, rew, gamma, next_state, turn)
        reward += rew

        if done:
            # battle is over, start up a new battle
            state, info = await env.reset(state_folder)
            state = torch.tensor(flatten(env.observation_space, state), dtype=torch.float32).unsqueeze(0)
            ep_reward.append(reward)
            reward = 0
            ep_steps.append(t)
            t = 0
        else:
            state = next_state
            t += 1

        # printing out incremental rewards if i want
        if (turn + 1) % 5 == 0:
            print(f"Turn {turn + 1}, reward: {ep_reward[-1:]}")
        # if (frame+1) % 10000 == 0:
        #     toc = time.time()      
        #     print(f"Frame: {frame+1}, reward: {ep_reward[-1:]}, steps: {ep_steps[-1:]}, time:{toc-tic}")
        #     tic = toc

    ep_reward.append(reward)  
    ep_steps.append(t)
    # save this model
    modelfile = "dirtybattlemodel.pt" if filename is None else filename
    torch.save(agent.q_net.state_dict(), modelfile)

    return ep_reward, ep_steps
    

# TODO implement
async def test(filepath = "battle_model.pt"):
    return None

async def parser():
   
    parser = argparse.ArgumentParser()
    parser.add_argument("mode", choices=["train", "test"], help="train or test mode")
    parser.add_argument('--new', action='store_true', help='Train and save a new model', default=False)
    parser.add_argument('--model', type=str, help='path to saved model', default=None)
    parser.add_argument('--s', type=str, help='path to training save states', default="/trainStates")
    args = parser.parse_args()

    env, device, agent, battle_net = await setup(reward_function=None, filepath=args.model, new = args.new)

    if args.mode == "train":
        await train(env, agent, gamma, n_steps, args.s, args.model)
    elif args.mode == "test":
        await test(filepath = args.model)

if __name__ == "__main__":
    asyncio.run(parser())