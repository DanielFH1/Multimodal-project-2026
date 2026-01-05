"""
Utility functions for the Multi-Modal Music Analysis project.

This module contains helper functions used across different components:
- File I/O operations
- Logging setup
- Configuration management
- Common data transformations
"""

import os
import json
import logging
from pathlib import Path
from typing import Any, Dict, List, Optional

# =============================================================================
# Setup logging
# =============================================================================
# 목적: 프로그램 실행 중 발생하는 이벤트를 기록합니다.
# DEBUG < INFO < WARNING < ERROR < CRITICAL 순으로 심각도가 높아집니다.
# =============================================================================

def setup_logger(name: str, log_file: Optional[str] = None, level=logging.INFO):
    """
    로거 설정 함수
    
    Args:
        name (str): 로거 이름 (보통 __name__ 사용)
        log_file (str, optional): 로그 파일 경로
        level: 로깅 레벨 (기본값: INFO)
    
    Returns:
        logging.Logger: 설정된 로거 객체
    
    Example:
        >>> logger = setup_logger(__name__)
        >>> logger.info("프로그램 시작!")
    """
    # formatter: 로그 메시지의 형식을 지정
    # %(asctime)s: 시간, %(name)s: 로거 이름, %(levelname)s: 로그 레벨
    formatter = logging.Formatter(
        '%(asctime)s - %(name)s - %(levelname)s - %(message)s'
    )
    
    # 로거 객체 생성
    logger = logging.getLogger(name)
    logger.setLevel(level)
    
    # 콘솔 출력 핸들러
    console_handler = logging.StreamHandler()
    console_handler.setFormatter(formatter)
    logger.addHandler(console_handler)
    
    # 파일 출력 핸들러 (옵션)
    if log_file:
        file_handler = logging.FileHandler(log_file)
        file_handler.setFormatter(formatter)
        logger.addHandler(file_handler)
    
    return logger


# =============================================================================
# File operations
# =============================================================================

def save_json(data: Dict[str, Any], filepath: str) -> None:
    """
    딕셔너리를 JSON 파일로 저장
    
    Args:
        data: 저장할 데이터 (딕셔너리)
        filepath: 저장 경로
    """
    os.makedirs(os.path.dirname(filepath), exist_ok=True)
    with open(filepath, 'w', encoding='utf-8') as f:
        json.dump(data, f, indent=2, ensure_ascii=False)


def load_json(filepath: str) -> Dict[str, Any]:
    """
    JSON 파일 로드
    
    Args:
        filepath: 로드할 파일 경로
    
    Returns:
        Dict: 로드된 데이터
    """
    with open(filepath, 'r', encoding='utf-8') as f:
        return json.load(f)


# =============================================================================
# Path management
# =============================================================================

def get_project_root() -> Path:
    """
    프로젝트 루트 디렉토리 경로 반환
    
    Returns:
        Path: 프로젝트 루트 경로
    """
    # __file__: 현재 파일의 경로
    # .parent: 부모 디렉토리
    # .parent.parent: 프로젝트 루트 (src/ 의 부모)
    return Path(__file__).parent.parent


# =============================================================================
# Data validation
# =============================================================================

def validate_data_shape(data, expected_shape: tuple, name: str = "Data"):
    """
    데이터의 shape이 예상과 일치하는지 검증
    
    Args:
        data: 검증할 데이터 (numpy array or tensor)
        expected_shape: 예상되는 shape
        name: 데이터 이름 (에러 메시지용)
    
    Raises:
        ValueError: shape이 일치하지 않을 경우
    """
    actual_shape = data.shape
    if actual_shape != expected_shape:
        raise ValueError(
            f"{name} shape mismatch! "
            f"Expected: {expected_shape}, Got: {actual_shape}"
        )


if __name__ == "__main__":
    # 테스트 코드
    logger = setup_logger(__name__)
    logger.info("utils.py 모듈 테스트 성공!")
    
    # 프로젝트 루트 확인
    root = get_project_root()
    logger.info(f"프로젝트 루트: {root}")
