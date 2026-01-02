import matplotlib.pyplot as plt

class Visualizer:
  """
  Monitoring dashboard : trajectory, sensor, estimated position
  """
  def __init__(self, title = "Robot Localization System"):
    self.title = title

  def plot_trajectory(self, gt_trajectory, label = "Ground Truth"):
    """
    plot the trajectory in 2d space, gt_trajectory : [N,3] type , numpy array of (x,y,theta)
    """
    plt.figure(figsize=(8,8))

    plt.plot(gt_trajectory[:,0], gt_trajectory[:,1], 'g-', linewidth=2, label=label)

    # Robot's starting point
    plt.plot(gt_trajectory[0,0], gt_trajectory[0,1], 'ro', label="Start")

    plt.title(self.title)
    plt.xlabel("X [meters]")
    plt.ylabel("Y [meters]")
    plt.legend()
    plt.grid(True)
    plt.axis('equal')

    plt.show()
print("Visualization.py generated!!!!!!!")
