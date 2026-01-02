import numpy as np

class TrajectoryGenerator:
    def __init__(self, dt=0.1):
        self.dt = dt

    def generate_circle(self, radius=5.0, speed=1.0, duration=20):
        t = np.arange(0, duration, self.dt)
        omega = speed / radius
        
        x = radius * np.cos(omega * t)
        y = radius * np.sin(omega * t)
        
        dx = -radius * omega * np.sin(omega * t)
        dy = radius * omega * np.cos(omega * t)
        theta = np.arctan2(dy, dx)
        
        return np.array([x, y, theta]).T

print("trajectory_generator.py 수정 및 생성 완료! ✨")
