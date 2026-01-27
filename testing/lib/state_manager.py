"""
Deployment state management.

Tracks deployment metadata and artifacts for later cleanup.
State files are saved as YAML in the testing directory.
"""

import yaml
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Any, Optional
import logging


logger = logging.getLogger("jambonz-test")


def create_deployment_state(
    terraform_dir: str,
    provider: str,
    variant: str,
    applied_by_script: bool = False
) -> Dict[str, Any]:
    """
    Create a new deployment state dictionary.

    Args:
        terraform_dir: Path to terraform directory
        provider: Cloud provider (e.g., "exoscale", "azure")
        variant: Deployment variant (e.g., "provision-vm-medium")
        applied_by_script: Whether terraform was applied by the script

    Returns:
        Dictionary containing deployment state structure
    """
    timestamp = datetime.now()
    deployment_id = f"{provider}-{variant}-{timestamp.strftime('%Y%m%d-%H%M%S')}"

    state = {
        'deployment_id': deployment_id,
        'timestamp': timestamp.isoformat(),
        'terraform_dir': str(Path(terraform_dir).resolve()),
        'provider': provider,
        'variant': variant,
        'terraform': {
            'applied_by_script': applied_by_script,
            'outputs': {}
        },
        'artifacts': {
            'dns_records': [],
            'tls_certificates': [],
            'api_resources': [],
            'credentials': {}
        },
        'test_results': {
            'status': 'pending',
            'steps_completed': [],
            'duration_seconds': 0
        }
    }

    return state


def save_state(state: Dict[str, Any], state_file: str = None) -> str:
    """
    Save deployment state to YAML file.

    Args:
        state: Deployment state dictionary
        state_file: Optional path to state file. If None, generates from deployment_id

    Returns:
        Path to saved state file
    """
    if not state_file:
        deployment_id = state.get('deployment_id', 'unknown')
        state_file = f".test-state-{deployment_id}.yaml"

    state_path = Path(state_file)

    # Ensure parent directory exists
    state_path.parent.mkdir(parents=True, exist_ok=True)

    with open(state_path, 'w') as f:
        yaml.dump(state, f, default_flow_style=False, sort_keys=False)

    logger.debug(f"Saved deployment state to {state_path}")
    return str(state_path)


def load_state(state_file: str) -> Dict[str, Any]:
    """
    Load deployment state from YAML file.

    Args:
        state_file: Path to state file

    Returns:
        Deployment state dictionary

    Raises:
        FileNotFoundError: If state file doesn't exist
        yaml.YAMLError: If state file is invalid
    """
    state_path = Path(state_file)

    if not state_path.exists():
        raise FileNotFoundError(f"State file not found: {state_file}")

    with open(state_path, 'r') as f:
        state = yaml.safe_load(f)

    logger.debug(f"Loaded deployment state from {state_path}")
    return state


def add_artifact(state: Dict[str, Any], artifact_type: str, artifact_data: Dict[str, Any]) -> None:
    """
    Add an artifact to the deployment state.

    Args:
        state: Deployment state dictionary
        artifact_type: Type of artifact (dns_records, api_resources, etc.)
        artifact_data: Artifact data to add
    """
    if 'artifacts' not in state:
        state['artifacts'] = {}

    if artifact_type not in state['artifacts']:
        state['artifacts'][artifact_type] = []

    # For non-list artifact types (like credentials), store as dict
    if artifact_type == 'credentials':
        state['artifacts']['credentials'].update(artifact_data)
    else:
        state['artifacts'][artifact_type].append(artifact_data)

    logger.debug(f"Added {artifact_type} artifact to state")


def update_test_results(
    state: Dict[str, Any],
    status: str,
    step: str = None,
    duration: float = None
) -> None:
    """
    Update test results in state.

    Args:
        state: Deployment state dictionary
        status: Test status (pending, success, failed, partial)
        step: Optional step that was completed
        duration: Optional test duration in seconds
    """
    if 'test_results' not in state:
        state['test_results'] = {
            'status': 'pending',
            'steps_completed': [],
            'duration_seconds': 0
        }

    state['test_results']['status'] = status

    if step and step not in state['test_results']['steps_completed']:
        state['test_results']['steps_completed'].append(step)

    if duration is not None:
        state['test_results']['duration_seconds'] = duration


def list_deployments(testing_dir: str = ".") -> List[Dict[str, Any]]:
    """
    List all active deployments by finding state files.

    Args:
        testing_dir: Directory to search for state files

    Returns:
        List of deployment state dictionaries
    """
    testing_path = Path(testing_dir)
    state_files = testing_path.glob(".test-state-*.yaml")

    deployments = []
    for state_file in state_files:
        try:
            state = load_state(str(state_file))
            state['_state_file'] = str(state_file.name)
            deployments.append(state)
        except Exception as e:
            logger.warning(f"Failed to load state file {state_file}: {e}")
            continue

    # Sort by timestamp (newest first)
    deployments.sort(key=lambda x: x.get('timestamp', ''), reverse=True)

    return deployments


def delete_state_file(state_file: str) -> bool:
    """
    Delete a state file.

    Args:
        state_file: Path to state file to delete

    Returns:
        True if deleted successfully
    """
    state_path = Path(state_file)

    if not state_path.exists():
        logger.warning(f"State file not found: {state_file}")
        return False

    try:
        state_path.unlink()
        logger.info(f"Deleted state file: {state_file}")
        return True
    except Exception as e:
        logger.error(f"Failed to delete state file {state_file}: {e}")
        return False
