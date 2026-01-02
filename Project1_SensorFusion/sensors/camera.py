import numpy as np 

class CameraSensor:
  """
  using camera, estimate the location by AprilTag
  In real world, camera has some noises.
  """
  def __init__(self,noise_std=[0.2,0.2,0.05]):
    self.noise_std = noise_std

  def observe(self,true_pose):
    """
    Get the true pose and return the noised estimate value
    """
    n_samples = true_pose.shape[0] # how many true poses are there?

    # generate Gaussian Noise
    noise_x = np.random.normal(0,self.noise_std[0], n_samples) # (mean, sd, total numbers)
    noise_y = np.random.normal(0,self.noise_std[1], n_samples)
    noise_theta = np.random.normal(0,self.noise_std[2], n_samples)

    observed_x = true_pose[:,0] + noise_x 
    observed_y = true_pose[:,1] + noise_y 
    observed_theta = true_pose[:,2] + noise_theta 

    return np.array([observed_x, observed_y, observed_theta]).T
print("Camera.py generated!!!!!!!!!!!!")
