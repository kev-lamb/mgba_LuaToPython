import torch
import math

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