"""
Configuration loader with environment variable substitution.

Loads YAML configuration files and substitutes environment variables
in the format ${VAR_NAME}.
"""

import os
import re
import yaml
from pathlib import Path
from typing import Dict, Any


def load_config(config_path: str) -> Dict[str, Any]:
    """
    Load YAML configuration file with environment variable substitution.

    Args:
        config_path: Path to the YAML configuration file

    Returns:
        Dictionary containing the loaded configuration

    Raises:
        FileNotFoundError: If the config file doesn't exist
        yaml.YAMLError: If the YAML is invalid
        ValueError: If a required environment variable is not set
    """
    config_file = Path(config_path).expanduser()

    if not config_file.exists():
        raise FileNotFoundError(f"Configuration file not found: {config_path}")

    # Read the file
    with open(config_file, 'r') as f:
        content = f.read()

    # Substitute environment variables
    content = _substitute_env_vars(content)

    # Parse YAML
    try:
        config = yaml.safe_load(content)
    except yaml.YAMLError as e:
        raise yaml.YAMLError(f"Invalid YAML in {config_path}: {e}")

    return config or {}


def _substitute_env_vars(content: str) -> str:
    """
    Substitute environment variables in the format ${VAR_NAME}.

    Skips commented lines (lines starting with #).

    Args:
        content: String content with ${VAR_NAME} placeholders

    Returns:
        Content with environment variables substituted

    Raises:
        ValueError: If a referenced environment variable is not set
    """
    # Process line by line to skip comments
    lines = content.split('\n')
    result_lines = []

    for line in lines:
        # Skip lines that are comments (start with # after stripping whitespace)
        if line.strip().startswith('#'):
            result_lines.append(line)
            continue

        # Find all ${VAR_NAME} patterns in non-comment lines
        pattern = r'\$\{([A-Z_][A-Z0-9_]*)\}'

        def replace_var(match):
            var_name = match.group(1)
            if var_name not in os.environ:
                raise ValueError(
                    f"Environment variable ${{{var_name}}} is referenced in config "
                    f"but not set. Please set it with: export {var_name}=your-value"
                )
            return os.environ[var_name]

        result_lines.append(re.sub(pattern, replace_var, line))

    return '\n'.join(result_lines)


def expand_path(path: str) -> Path:
    """
    Expand a path, resolving ~ and environment variables.

    Args:
        path: Path string to expand

    Returns:
        Expanded Path object
    """
    return Path(os.path.expandvars(os.path.expanduser(path)))
