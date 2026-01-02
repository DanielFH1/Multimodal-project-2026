import numpy as np

class ParticleFilter:
    """
    수많은 파티클(입자)을 생성하여 로봇의 위치를 추정합니다.
    '확률적 샘플링'을 통해 비선형적인 움직임을 완벽하게 추적할 수 있습니다.
    """
    def __init__(self, num_particles=500, dt=0.1):
        self.num_particles = num_particles
        self.dt = dt
        
        # 1. 파티클 초기화: [x, y, theta] 상태를 가진 수많은 점들을 만듭니다.
        # 처음에는 로봇의 위치를 모르므로 (0,0,0) 근처에 뿌립니다.
        self.particles = np.zeros((num_particles, 3))
        
        # 2. 가중치(Weights) 초기화: 모든 파티클은 처음에 동일한 확률(1/N)을 가집니다.
        self.weights = np.ones(num_particles) / num_particles

    def predict(self, u, noise=[0.1, 0.1, 0.05]):
        """
        [예측 단계] 모든 파티클을 로봇의 움직임(IMU 데이터 u)에 따라 이동시킵니다.
        이때, 각 파티클에 무작위 노이즈를 섞어 '불확실성'을 표현합니다.
        """
        v = u[0]
        omega = u[1]
        
        # 각 파티클마다 서로 다른 노이즈를 더해 미래 위치를 예측합니다.
        self.particles[:, 0] += (v * np.cos(self.particles[:, 2]) * self.dt + 
                                 np.random.normal(0, noise[0], self.num_particles))
        self.particles[:, 1] += (v * np.sin(self.particles[:, 2]) * self.dt + 
                                 np.random.normal(0, noise[1], self.num_particles))
        self.particles[:, 2] += (omega * self.dt + 
                                 np.random.normal(0, noise[2], self.num_particles))

    def update(self, z, R=[0.1, 0.1, 0.05]):
        """
        [보정 단계] 실제 센서 측정값(z)과 각 파티클의 위치를 비교합니다.
        측정값과 가까운 파티클일수록 높은 가중치(Weight)를 부여합니다.
        """
        # 측정값 z와 파티클들 사이의 거리(오차)를 계산합니다.
        distances = np.linalg.norm(self.particles[:, :2] - z[:2], axis=1)
        
        # 가우시안 확률 밀도 함수를 사용하여 가중치를 계산합니다.
        # 거리가 가까울수록 가중치(w)는 1에 가까워지고, 멀수록 0에 가까워집니다.
        self.weights *= np.exp(-distances**2 / (2 * R[0]**2))
        
        # 가중치의 총합이 1이 되도록 정규화(Normalization)합니다.
        self.weights += 1e-300 # 0으로 나누기 방지
        self.weights /= np.sum(self.weights)

    def resample(self):
        """
        [재샘플링 단계] 가중치가 높은(정답에 가까운) 파티클은 복제하고, 
        가중치가 낮은 파티클은 제거하여 새로운 파티클 집합을 만듭니다.
        """
        # np.random.choice를 사용하여 확률적으로 파티클을 다시 뽑습니다.
        indices = np.random.choice(np.arange(self.num_particles), 
                                   size=self.num_particles, 
                                   p=self.weights)
        self.particles = self.particles[indices]
        self.weights = np.ones(self.num_particles) / self.num_particles

    def estimate(self):
        """
        현재 수많은 파티클들의 평균 위치를 계산하여 최종 '로봇의 위치'로 반환합니다.
        """
        return np.mean(self.particles, axis=0)

print("particle_filter.py 생성 완료! 🎲")
