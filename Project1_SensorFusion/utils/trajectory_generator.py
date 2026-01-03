import numpy as np

class TrajectoryGenerator:
    def __init__(self, dt=0.1):
        self.dt = dt

    def generate_circle(self, radius=5.0, speed=1.0, duration=20):
        t = np.arange(0, duration, self.dt)
        omega = speed / radius
        x = radius * np.cos(omega * t)
        y = radius * np.sin(omega * t)
        
        # 방향(theta) 계산: 속도 벡터의 아크탄젠트
        dx = -radius * omega * np.sin(omega * t)
        dy = radius * omega * np.cos(omega * t)
        theta = np.arctan2(dy, dx)
        return np.array([x, y, theta]).T

    def generate_eight_shape(self, size=5.0, duration=40):
        """
        8자 모양(Lemniscate of Gerono) 경로를 생성합니다.
        로봇이 좌우 회전을 번갈아 가며 수행하므로 필터 성능 테스트에 최적입니다.
        """
        t = np.arange(0, duration, self.dt)
        # 8자 곡선 공식
        scale = size
        t_scaled = 0.2 * t # 경로 속도 조절
        
        x = scale * np.sin(t_scaled)
        y = scale * np.sin(t_scaled) * np.cos(t_scaled)
        
        # 수치 미분을 통한 방향(theta) 계산
        dx = np.gradient(x, self.dt)
        dy = np.gradient(y, self.dt)
        theta = np.arctan2(dy, dx)
        
        return np.array([x, y, theta]).T

    def generate_lissajous(self, A=5.0, B=5.0, a=3, b=2, delta=np.pi/2, duration=40):
        """
        Creative한 리사주 곡선을 생성합니다. (3:2 비율의 복잡한 궤적)
        복잡한 커브가 많아 센서 융합 알고리즘의 한계를 시험하기 좋습니다.
        """
        t = np.arange(0, duration, self.dt)
        t_scaled = 0.1 * t
        
        x = A * np.sin(a * t_scaled + delta)
        y = B * np.sin(b * t_scaled)
        
        dx = np.gradient(x, self.dt)
        dy = np.gradient(y, self.dt)
        theta = np.arctan2(dy, dx)
        
        return np.array([x, y, theta]).T