# Multimodal Sensor Fusion for Autonomous State Estimation

## 📌 Overview
This project implements a robust **Multimodal Sensor Fusion System** designed to estimate the state of an autonomous agent in real-time. By integrating disparate data sources—**Vision (Landmark-based), LiDAR (Scan-matching), and IMU (Inertial)—**the system demonstrates how probabilistic models can overcome the inherent limitations and noise of individual sensors.

The core objective is to showcase high-fidelity localization through advanced filtering techniques, emphasizing the synergy between high-frequency motion prediction and contextual measurement updates.

## 🚀 Key Technical Features

### 1. Data Simulation & Noise Modeling
- **Synthetic Trajectory Generation**: Implemented a dynamic motion engine to create ground-truth paths (circular/complex trajectories).
- **Realistic Sensor Perturbation**: Modeled sensor-specific errors including Gaussian noise for Vision/LiDAR and cumulative drift for IMU to simulate real-world environmental challenges.

### 2. Sensor Fusion Algorithms
- **Extended Kalman Filter (EKF)**: 
  - Implemented a linearized state-space model for non-linear robot kinematics.
  - Utilized Jacobian matrices for covariance propagation to maintain optimal state estimates.
- **Particle Filter (Sequential Monte Carlo)**: 
  - Developed a non-parametric filter to handle non-Gaussian noise and multi-modal distributions.
  - Implemented importance sampling and systematic resampling to prevent particle deprivation.

### 3. Multimodal Integration Strategy
- **Context-Aware Fusion**: The system dynamically weighs sensor inputs based on their reliability. 
- **Temporal Continuity**: Uses high-frequency IMU data for motion prediction (Dead Reckoning) while leveraging Vision and LiDAR for absolute global corrections.

## 🛠 System Architecture
The project is structured with a modular object-oriented approach for scalability:
- `sensors/`: Simulation of Vision (AprilTag detection logic), LiDAR (ICP-based matching), and IMU (gyro/accel integration).
- `fusion/`: Core logic for EKF and Particle Filter implementation.
- `utils/`: Trajectory generation and real-time visualization tools.

## 📈 Performance Analysis
The system evaluates accuracy using **Root Mean Square Error (RMSE)** against the ground truth. 
- **EKF** provides a computationally efficient, smooth trajectory.
- **Particle Filter** excels in handling highly non-linear movements and recovery from sudden sensor failures.

## 💡 Conceptual Insights
This project explores the fundamental philosophy of **Multimodal AI**: 
*Just as language models fuse disparate tokens for better context understanding, autonomous systems fuse different sensor modalities to build a consistent "world view."* By implementing these filters from scratch, I have gained deep insights into:
- **Probabilistic State Estimation** (Bayesian Inference)
- **Handling Noisy, Asynchronous Data Streams**
- **The Trade-off between Precision and Computational Cost**

---
## How to Run
```bash
python main.py
