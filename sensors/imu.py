import numpy as np 

class ImuSensor:
  """
  Estimate robot's accerometer, gyroscope.
  IMU는 데이터가 아주 빠르게 들어오지만(high freq.), 시간이 지날수록 오차누적(drift현상)
  """
  def __init__(self, dt=0.1, accel_noise=0.05, gyro_noise=0.01):
    self.dt = dt
    self.accel_noise = accel_noise 
    self.gyro_noise = gyro_noise

  def generate_measurements(self, true_path):
    """
    Using true path, calculate accelerate, angular velocity
    """
    n = len(true_path)

    vx = np.diff(true_path[:,0]) / self.dt 
    vy = np.diff(true_path[:,1])/self.dt 
    v = np.sqrt(vx**2 + vy**2) # linear velocity

    omega = np.diff(true_path[:,2]) / self.dt # angular velocity

    ax = np.diff(vx)/self.dt 
    ay = np.diff(vy)/self.dt 

    omega = np.append(omega, omega[-1])
    ax = np.append(ax, [ax[-1], ax[-1]])
    ay = np.append(ay, [ay[-1], ay[-1]])

    noisy_ax = ax + np.random.normal(0,self.accel_noise, len(ax))
    noisy_ay = ay + np.random.normal(0,self.accel_noise, len(ay))
    noisy_omega = omega + np.random.normal(0,self.gyro_noise, len(omega))

    return np.array([noisy_ax, noisy_ay, noisy_omega]).T

print("generated imu.py!!!!!!!!!!!")
