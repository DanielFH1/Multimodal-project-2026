import numpy as np 

class LidarSensor:
  """
  let's match the Lidar scan data with map (ICP)
  Lidar is more accurate on estimate distance than camera
  but, in featureless location(like hallway) it confused which is front and which is back
  """

  def __init__(self,noise_std=[0.1,0.1,0.02]): # since the lidar is more accurate than camera, smaller value than camera
    self.noise_std = noise_std 
  
  def observe(self,true_pose):
    """
    Get the true pose and return the estimated location by lidar.
    """
    n_samples = true_pose.shape[0]

    noise_x = np.random.normal(0, self.noise_std[0], n_samples)
    noise_y = np.random.normal(0, self.noise_std[1], n_samples)
    noise_theta = np.random.normal(0, self.noise_std[2], n_samples)

    observed_x = true_pose[:,0] + noise_x 
    observed_y = true_pose[:,1] + noise_y
    observed_theta = true_pose[:,2] + noise_theta 

    return np.array([observed_x, observed_y, observed_theta]).T 

print("generated lidar.py!!!!!!!!!")
