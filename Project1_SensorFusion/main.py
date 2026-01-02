import numpy as np
import matplotlib.pyplot as plt
# 우리가 만든 모듈들을 불러옵니다.
from utils.trajectory_generator import TrajectoryGenerator
from utils.visualization import Visualizer
from sensors.camera import CameraSensor
from sensors.lidar import LidarSensor
from sensors.imu import ImuSensor
from fusion.ekf import ExtendedKalmanFilter
from fusion.particle_filter import ParticleFilter

def run_simulation():
    # 1. 시뮬레이션 파라미터 설정
    dt = 0.1           # 시간 간격 (0.1초)
    duration = 31.5    # 총 주행 시간 (초) - 원을 한 바퀴 조금 넘게 도는 시간
    
    # 2. 객체 초기화 (연장통 준비)
    generator = TrajectoryGenerator(dt=dt)
    visualizer = Visualizer(title="Bear Robotics & XL8: Multimodal Fusion Demo")
    
    # 센서들: 각기 다른 노이즈 특성을 가짐
    camera = CameraSensor(noise_std=[0.3, 0.3, 0.1]) # 카메라는 조금 더 오차가 큼
    lidar = LidarSensor(noise_std=[0.1, 0.1, 0.03])  # 라이다는 상대적으로 정확함
    imu = ImuSensor(dt=dt)
    
    # 알고리즘들: 오차를 줄여줄 두뇌
    ekf = ExtendedKalmanFilter(dt=dt)
    pf = ParticleFilter(num_particles=500, dt=dt)
    
    # 3. 데이터 생성 (가상 세계 구축)
    true_path = generator.generate_circle(radius=5.0, speed=1.0, duration=duration)
    cam_obs = camera.observe(true_path)
    lidar_obs = lidar.observe(true_path)
    imu_data = imu.generate_measurements(true_path)
    
    # 결과를 담을 그릇
    ekf_estimated_path = []
    pf_estimated_path = []
    
    # 4. 실시간 루프 (Real-time Loop) 시뮬레이션
    # 로봇이 움직이는 매 순간(Step)마다 센서값을 읽고 위치를 계산합니다.
    for i in range(len(true_path)):
        # [A] 예측(Predict): IMU의 각속도(omega)와 일정한 속도(v=1.0)를 이용
        # u = [선속도, 각속도]
        u = [1.0, imu_data[i, 2]] 
        ekf.predict(u)
        pf.predict(u)
        
        # [B] 보정(Update): 카메라와 라이다의 정보를 융합(Fusion)하여 입력
        # 여기서는 두 센서값의 평균을 내어 '멀티모달 통합 데이터'로 사용합니다.
        # 실제로는 가중치를 다르게 주는 'Late Fusion' 전략을 씁니다.
        z_fused = (cam_obs[i] + lidar_obs[i]) / 2.0
        
        ekf.update(z_fused)
        pf.update(z_fused)
        pf.resample() # 파티클 필터는 업데이트 후 우수한 입자만 남기는 과정이 필수!
        
        # [C] 현재의 '최선의 추측' 기록
        ekf_estimated_path.append(ekf.x.copy())
        pf_estimated_path.append(pf.estimate().copy())
        
    # 리스트를 계산하기 편하게 넘파이 배열로 변환
    ekf_estimated_path = np.array(ekf_estimated_path)
    pf_estimated_path = np.array(pf_estimated_path)
    
    # 5. 결과 시각화 (성과 보고)
    plt.figure(figsize=(12, 10))
    # 정답 경로 (초록 실선)
    plt.plot(true_path[:, 0], true_path[:, 1], 'g-', linewidth=3, label="Ground Truth (Real)")
    # 센서 데이터 (흐릿한 점들 - 노이즈 확인용)
    plt.scatter(cam_obs[::5, 0], cam_obs[::5, 1], c='r', s=5, alpha=0.3, label="Camera (Noisy)")
    plt.scatter(lidar_obs[::5, 0], lidar_obs[::5, 1], c='b', s=5, alpha=0.3, label="LiDAR (Noisy)")
    # 알고리즘 결과 (점선)
    plt.plot(ekf_estimated_path[:, 0], ekf_estimated_path[:, 1], 'b--', linewidth=2, label="EKF Estimate")
    plt.plot(pf_estimated_path[:, 0], pf_estimated_path[:, 1], 'r:', linewidth=2, label="Particle Filter Estimate")
    
    plt.legend()
    plt.title("Sensor Fusion Result: How Algorithms Recover Truth from Noise")
    plt.xlabel("X [m]")
    plt.ylabel("Y [m]")
    plt.axis('equal')
    plt.grid(True)
    plt.savefig("fusion_result.png") # 결과를 이미지 파일로 저장
    plt.show()

if __name__ == "__main__":
    run_simulation()

print("main.py 생성 및 시뮬레이션 준비 완료! 🏁")
