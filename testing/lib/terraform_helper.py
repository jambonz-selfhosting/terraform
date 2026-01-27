"""
Terraform operations wrapper.

Provides functions to run terraform commands (apply, destroy, output)
and parse the results.
"""

import os
import json
import subprocess
from pathlib import Path
from typing import Dict, Any, Optional
import logging


logger = logging.getLogger("jambonz-test")


class TerraformError(Exception):
    """Raised when terraform commands fail."""
    pass


def set_terraform_env_vars(provider: str, config: Dict[str, Any]) -> Dict[str, str]:
    """
    Set environment variables for terraform based on provider and config.

    Args:
        provider: Cloud provider name (exoscale, azure, gcp, aws)
        config: Configuration dictionary from config.yaml

    Returns:
        Dictionary of environment variables that were set

    Raises:
        TerraformError: If provider credentials are missing or invalid
    """
    terraform_config = config.get('terraform', {})
    provider_config = terraform_config.get(provider, {})

    env_vars = {}

    if provider == 'exoscale':
        api_key = provider_config.get('api_key')
        api_secret = provider_config.get('api_secret')

        if not api_key or not api_secret:
            raise TerraformError(
                f"Exoscale credentials not found in config. "
                f"Please set terraform.exoscale.api_key and terraform.exoscale.api_secret"
            )

        env_vars['EXOSCALE_API_KEY'] = api_key
        env_vars['EXOSCALE_API_SECRET'] = api_secret
        logger.debug("Set EXOSCALE_API_KEY and EXOSCALE_API_SECRET from config")

    elif provider == 'azure':
        for key in ['subscription_id', 'tenant_id', 'client_id', 'client_secret']:
            value = provider_config.get(key)
            if value:
                env_var_name = f"ARM_{key.upper()}"
                env_vars[env_var_name] = value
        logger.debug(f"Set {len(env_vars)} Azure environment variables from config")

    elif provider == 'gcp':
        credentials_file = provider_config.get('credentials_file')
        project = provider_config.get('project')
        if credentials_file:
            env_vars['GOOGLE_APPLICATION_CREDENTIALS'] = credentials_file
        if project:
            env_vars['GCP_PROJECT'] = project
        logger.debug(f"Set {len(env_vars)} GCP environment variables from config")

    elif provider == 'aws':
        for key in ['access_key_id', 'secret_access_key', 'region']:
            value = provider_config.get(key)
            if value:
                env_var_name = f"AWS_{key.upper()}"
                env_vars[env_var_name] = value
        logger.debug(f"Set {len(env_vars)} AWS environment variables from config")

    else:
        logger.warning(f"Unknown provider '{provider}', no credentials set")

    # Set environment variables in current process
    for key, value in env_vars.items():
        os.environ[key] = value

    return env_vars


def terraform_apply(terraform_dir: str, var_file: str = None, auto_approve: bool = True) -> bool:
    """
    Run terraform apply in the specified directory.

    Args:
        terraform_dir: Path to terraform configuration directory
        var_file: Optional path to terraform vars file
        auto_approve: Whether to auto-approve (default: True)

    Returns:
        True if successful

    Raises:
        TerraformError: If terraform apply fails
    """
    tf_dir = Path(terraform_dir).resolve()

    if not tf_dir.exists():
        raise TerraformError(f"Terraform directory not found: {terraform_dir}")

    cmd = ["terraform", "apply"]

    if var_file:
        cmd.extend(["-var-file", var_file])

    if auto_approve:
        cmd.append("-auto-approve")

    logger.info(f"Running: {' '.join(cmd)} in {tf_dir}")
    logger.debug(f"Full command: {cmd}")

    try:
        # Stream output in real-time
        process = subprocess.Popen(
            cmd,
            cwd=tf_dir,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            bufsize=1,
            universal_newlines=True
        )

        # Read and log output line by line
        for line in process.stdout:
            line = line.rstrip()
            if line:
                logger.info(f"  {line}")

        # Wait for process to complete
        process.wait(timeout=1800)

        if process.returncode != 0:
            raise TerraformError(f"Terraform apply failed with exit code {process.returncode}")

        logger.info("✓ Terraform apply completed successfully")
        return True

    except subprocess.TimeoutExpired:
        process.kill()
        raise TerraformError("Terraform apply timed out after 30 minutes")
    except FileNotFoundError:
        raise TerraformError("Terraform command not found. Is terraform installed?")


def terraform_destroy(terraform_dir: str, var_file: str = None, auto_approve: bool = True) -> bool:
    """
    Run terraform destroy in the specified directory.

    Args:
        terraform_dir: Path to terraform configuration directory
        var_file: Optional path to terraform vars file
        auto_approve: Whether to auto-approve (default: True)

    Returns:
        True if successful

    Raises:
        TerraformError: If terraform destroy fails
    """
    tf_dir = Path(terraform_dir).resolve()

    if not tf_dir.exists():
        raise TerraformError(f"Terraform directory not found: {terraform_dir}")

    cmd = ["terraform", "destroy"]

    if var_file:
        cmd.extend(["-var-file", var_file])

    if auto_approve:
        cmd.append("-auto-approve")

    logger.info(f"Running: {' '.join(cmd)} in {tf_dir}")

    try:
        # Stream output in real-time
        process = subprocess.Popen(
            cmd,
            cwd=tf_dir,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            bufsize=1,
            universal_newlines=True
        )

        # Read and log output line by line
        for line in process.stdout:
            line = line.rstrip()
            if line:
                logger.info(f"  {line}")

        # Wait for process to complete
        process.wait(timeout=1800)

        if process.returncode != 0:
            raise TerraformError(f"Terraform destroy failed with exit code {process.returncode}")

        logger.info("✓ Terraform destroy completed successfully")
        return True

    except subprocess.TimeoutExpired:
        process.kill()
        raise TerraformError("Terraform destroy timed out after 30 minutes")
    except FileNotFoundError:
        raise TerraformError("Terraform command not found. Is terraform installed?")


def get_terraform_outputs(terraform_dir: str) -> Dict[str, Any]:
    """
    Get terraform outputs as a dictionary.

    Args:
        terraform_dir: Path to terraform configuration directory

    Returns:
        Dictionary of terraform outputs

    Raises:
        TerraformError: If terraform output command fails
    """
    tf_dir = Path(terraform_dir).resolve()

    if not tf_dir.exists():
        raise TerraformError(f"Terraform directory not found: {terraform_dir}")

    cmd = ["terraform", "output", "-json"]

    logger.debug(f"Getting terraform outputs from {tf_dir}")

    try:
        result = subprocess.run(
            cmd,
            cwd=tf_dir,
            capture_output=True,
            text=True,
            timeout=30
        )

        if result.returncode != 0:
            error_msg = f"Terraform output failed with exit code {result.returncode}"
            if result.stderr:
                error_msg += f"\n{result.stderr}"
            raise TerraformError(error_msg)

        # Parse JSON output
        try:
            outputs_raw = json.loads(result.stdout)
        except json.JSONDecodeError as e:
            raise TerraformError(f"Failed to parse terraform output JSON: {e}")

        # Extract values from terraform output format
        # Terraform output format: {"output_name": {"value": actual_value, "type": "string"}}
        outputs = {}
        for key, value_dict in outputs_raw.items():
            if isinstance(value_dict, dict) and 'value' in value_dict:
                outputs[key] = value_dict['value']
            else:
                outputs[key] = value_dict

        logger.debug(f"Retrieved {len(outputs)} terraform outputs")
        return outputs

    except subprocess.TimeoutExpired:
        raise TerraformError("Terraform output timed out")
    except FileNotFoundError:
        raise TerraformError("Terraform command not found. Is terraform installed?")


def extract_provider_variant(terraform_dir: str) -> tuple[str, str]:
    """
    Extract provider and variant from terraform directory path.

    Args:
        terraform_dir: Path like ./exoscale/provision-vm-medium

    Returns:
        Tuple of (provider, variant) e.g., ("exoscale", "provision-vm-medium")
    """
    path = Path(terraform_dir).resolve()
    parts = path.parts

    # Find indices - look for known providers
    known_providers = ['exoscale', 'azure', 'gcp', 'aws']

    provider = None
    variant = None

    for i, part in enumerate(parts):
        if part in known_providers:
            provider = part
            # Next part should be the variant
            if i + 1 < len(parts):
                variant = parts[i + 1]
            break

    if not provider or not variant:
        # Fallback: use last two parts
        if len(parts) >= 2:
            provider = parts[-2]
            variant = parts[-1]
        else:
            provider = "unknown"
            variant = parts[-1] if parts else "unknown"

    return provider, variant
