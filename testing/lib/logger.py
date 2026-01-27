"""
Dual logging setup - logs to both file and stdout simultaneously.

Provides real-time monitoring capability via tail -f while preserving
complete logs for later review.
"""

import logging
import sys
from datetime import datetime
from pathlib import Path
from typing import Tuple


def setup_logger(log_file: str = None) -> Tuple[logging.Logger, str]:
    """
    Setup dual logger that writes to both file and stdout.

    Args:
        log_file: Path to log file. If None, generates timestamp-based filename

    Returns:
        Tuple of (logger instance, log file path)
    """
    # Generate default log file name if not provided
    if not log_file:
        timestamp = datetime.now().strftime("%Y-%m-%d-%H%M%S")
        log_file = f"test-cloud-init-{timestamp}.log"

    # Ensure log file directory exists
    log_path = Path(log_file)
    log_path.parent.mkdir(parents=True, exist_ok=True)

    # Create logger
    logger = logging.getLogger("jambonz-test")
    logger.setLevel(logging.DEBUG)

    # Clear any existing handlers (in case logger was already configured)
    logger.handlers.clear()

    # File handler (detailed logs with timestamps)
    file_handler = logging.FileHandler(log_file, mode='w', encoding='utf-8')
    file_handler.setLevel(logging.DEBUG)
    file_formatter = logging.Formatter(
        '%(asctime)s [%(levelname)s] %(message)s',
        datefmt='%Y-%m-%d %H:%M:%S'
    )
    file_handler.setFormatter(file_formatter)

    # Console handler (clean, user-friendly output)
    console_handler = logging.StreamHandler(sys.stdout)
    console_handler.setLevel(logging.INFO)
    console_formatter = logging.Formatter('%(message)s')
    console_handler.setFormatter(console_formatter)

    # Add both handlers
    logger.addHandler(file_handler)
    logger.addHandler(console_handler)

    # Initial log message
    logger.info(f"Logging to: {log_file}")
    logger.info("")  # Blank line for readability

    return logger, log_file
