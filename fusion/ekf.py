import numpy as np

class ExtendedKalmanFilter:
    """
    EKF는 예측(Predict)과 보정(Update)의 반복으로 로봇의 위치를 추정합니다.
    Bear Robotics JD에 등장하는 'State Estimation'의 실체입니다.
    """
    def __init__(self, dt=0.1):
        self.dt = dt
        
        # 1. 상태 벡터 (State Vector): [x, y, theta]
        # 로봇의 현재 위치와 방향을 저장합니다.
        self.x = np.zeros(3)
        
        # 2. 공분산 행렬 (Covariance Matrix): P
        # 내 추측이 얼마나 '불확실'한지 나타내는 행렬입니다. 
        # 처음엔 모르니까 큰 값(1.0)으로 시작해서 점점 줄여나갑니다.
        self.P = np.eye(3) * 1.0
        
        # 3. 프로세스 노이즈 (Process Noise): Q
        # 로봇이 움직일 때 발생하는 물리적 불확실성(바닥 미끄러짐 등)을 모델링합니다.
        self.Q = np.diag([0.01, 0.01, 0.01])
        
        # 4. 측정 노이즈 (Measurement Noise): R
        # 센서 자체의 오차를 정의합니다. (우리가 앞서 설정한 noise_std와 대응됨)
        self.R = np.diag([0.1, 0.1, 0.05])

    def predict(self, u):
        """
        [예측 단계] IMU 데이터(u = [v, omega])를 받아 다음 위치를 추측합니다.
        u[0]: 선속도 (v), u[1]: 각속도 (omega)
        """
        v = u[0]
        omega = u[1]
        theta = self.x[2]

        # 1. 상태 전이 (Motion Model)
        # 현재 위치 + (속도 * 시간 * 방향) = 다음 위치
        self.x[0] += v * np.cos(theta) * self.dt
        self.x[1] += v * np.sin(theta) * self.dt
        self.x[2] += omega * self.dt

        # 2. 야코비안 행렬 (F) 계산
        # 비선형적인 움직임을 직선으로 근사화하기 위해 미분한 행렬입니다.
        # 이 행렬이 있어야 '불확실성(P)'이 어떻게 전파되는지 계산할 수 있습니다.
        F = np.array([
            [1, 0, -v * np.sin(theta) * self.dt],
            [0, 1,  v * np.cos(theta) * self.dt],
            [0, 0, 1]
        ])

        # 3. 불확실성 업데이트: P = FPF' + Q
        # 시간이 지날수록 예측만 하면 불확실성(P)은 점점 커집니다.
        self.P = F @ self.P @ F.T + self.Q

    def update(self, z):
        """
        [보정 단계] 외부 센서(Camera/LiDAR)의 관측값(z)을 보고 예측치를 수정합니다.
        """
        # 1. 잔차(Residual) 계산: y = 진짜 측정값 - 내 예측값
        # 내가 예측한 것과 실제 센서가 본 것의 차이를 구합니다.
        y = z - self.x

        # 2. 칼만 이득 (Kalman Gain): K
        # "내 예측력을 더 믿을까? 아니면 센서를 더 믿을까?"를 결정하는 가중치입니다.
        # 센서가 정확하면 센서를 더 많이 반영하고, 아니면 예측치를 고수합니다.
        S = self.P + self.R
        K = self.P @ np.linalg.inv(S)

        # 3. 최종 상태 보정: x = x + Ky
        # 칼만 이득만큼 잔차를 반영하여 위치를 최종 수정합니다.
        self.x = self.x + K @ y

        # 4. 불확실성 업데이트: P = (I - KH)P
        # 정보를 얻었으므로 나의 불확실성(P)은 다시 줄어듭니다.
        self.P = (np.eye(3) - K) @ self.P

print("ekf.py 생성 완료! 🧠")
