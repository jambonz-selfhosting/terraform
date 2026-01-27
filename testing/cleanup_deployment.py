#!/usr/bin/env python3
"""
Cleanup deployment artifacts created during testing.

Reads deployment state file and removes all artifacts:
- DNS records (future phases)
- API resources (future phases)
- TLS certificates (optional)
- Terraform infrastructure (optional)
- State file itself

Usage:
    # Cleanup artifacts only (leave terraform running):
    python cleanup_deployment.py --state-file .test-state-xyz.yaml

    # Cleanup everything including terraform destroy:
    python cleanup_deployment.py --state-file .test-state-xyz.yaml --destroy-terraform

    # Auto-approve terraform destroy (no prompt):
    python cleanup_deployment.py --state-file .test-state-xyz.yaml --destroy-terraform --auto-approve
"""

import sys
import click
from pathlib import Path

# Add lib directory to path
sys.path.insert(0, str(Path(__file__).parent / "lib"))

from state_manager import load_state, delete_state_file
from terraform_helper import terraform_destroy, set_terraform_env_vars, extract_provider_variant, TerraformError
from config_loader import load_config
from logger import setup_logger


def cleanup_deployment(
    state_file: str,
    destroy_terraform: bool = False,
    auto_approve: bool = False,
    config_file: str = 'config.yaml',
    logger=None
):
    """
    Cleanup deployment artifacts.

    Args:
        state_file: Path to deployment state file
        destroy_terraform: Whether to run terraform destroy
        auto_approve: Auto-approve terraform destroy (no prompt)
        logger: Logger instance (creates new one if None)

    Returns:
        True if cleanup successful
    """
    # Setup logger if not provided
    if logger is None:
        logger, _ = setup_logger()

    logger.info("=" * 60)
    logger.info("Jambonz Deployment Cleanup")
    logger.info("=" * 60)
    logger.info("")

    # Load state file
    try:
        state = load_state(state_file)
        logger.info(f"Loaded state file: {state_file}")
        logger.info(f"Deployment ID: {state.get('deployment_id', 'unknown')}")
        logger.info(f"Provider: {state.get('provider', 'unknown')}")
        logger.info(f"Variant: {state.get('variant', 'unknown')}")
        logger.info(f"Timestamp: {state.get('timestamp', 'unknown')}")
        logger.info("")
    except FileNotFoundError:
        logger.error(f"State file not found: {state_file}")
        return False
    except Exception as e:
        logger.error(f"Failed to load state file: {e}")
        return False

    cleanup_successful = True

    # Cleanup DNS records (Phase 2)
    dns_records = state.get('artifacts', {}).get('dns_records', [])
    if dns_records:
        logger.info("[DNS Cleanup]")
        logger.info(f"Found {len(dns_records)} DNS record(s) to delete")
        logger.info("DNS cleanup not yet implemented (Phase 2)")
        logger.info("Please manually delete DNS records if needed")
        logger.info("")
        # TODO: Implement in Phase 2
        # for record in dns_records:
        #     logger.info(f"  Deleting {record['domain']} ({record['record_type']})...")

    # Cleanup API resources (Phase 6)
    api_resources = state.get('artifacts', {}).get('api_resources', [])
    if api_resources:
        logger.info("[API Resource Cleanup]")
        logger.info(f"Found {len(api_resources)} API resource(s) to delete")
        logger.info("API cleanup not yet implemented (Phase 6)")
        logger.info("Please manually delete API resources via Jambonz portal if needed")
        logger.info("")
        # TODO: Implement in Phase 6
        # for resource in api_resources:
        #     logger.info(f"  Deleting {resource['type']}: {resource['name']}...")

    # Cleanup TLS certificates (optional - they expire automatically)
    tls_certs = state.get('artifacts', {}).get('tls_certificates', [])
    if tls_certs:
        logger.info("[TLS Certificate Cleanup]")
        logger.info(f"Found {len(tls_certs)} certificate(s)")
        logger.info("TLS certificates will expire automatically (90 days)")
        logger.info("No action needed unless you want to revoke them manually")
        logger.info("")

    # Terraform destroy
    if destroy_terraform:
        logger.info("[Terraform Cleanup]")

        terraform_dir = state.get('terraform_dir')
        if not terraform_dir:
            logger.error("No terraform_dir in state file")
            cleanup_successful = False
        else:
            # Load config and set terraform credentials
            try:
                config_data = load_config(config_file)
                provider = state.get('provider', 'unknown')
                set_terraform_env_vars(provider, config_data)
                logger.debug("Terraform credentials configured from config file")
            except Exception as e:
                logger.error(f"Failed to set terraform credentials: {e}")
                logger.error("Terraform destroy may fail without credentials")
                # Continue anyway in case credentials are in environment

            applied_by_script = state.get('terraform', {}).get('applied_by_script', False)

            if not applied_by_script and not auto_approve:
                logger.warning("Warning: Terraform was not applied by the test script.")
                logger.warning(f"Terraform directory: {terraform_dir}")
                logger.info("")
                response = input("Continue with terraform destroy? [y/N]: ")
                if response.lower() not in ['y', 'yes']:
                    logger.info("Skipping terraform destroy")
                    cleanup_successful = False
                else:
                    auto_approve = True  # User manually approved

            if applied_by_script or auto_approve:
                logger.info(f"Running terraform destroy in {terraform_dir}...")
                try:
                    terraform_destroy(
                        terraform_dir=terraform_dir,
                        auto_approve=auto_approve
                    )
                    logger.info("✓ Terraform destroy completed successfully")
                except TerraformError as e:
                    logger.error(f"✗ Terraform destroy failed: {e}")
                    cleanup_successful = False

        logger.info("")

    # Delete state file
    if cleanup_successful:
        logger.info("[State File Cleanup]")
        logger.info(f"Deleting state file: {state_file}")
        if delete_state_file(state_file):
            logger.info("✓ State file deleted")
        else:
            logger.warning("✗ Failed to delete state file")
            cleanup_successful = False
        logger.info("")

    # Summary
    logger.info("=" * 60)
    if cleanup_successful:
        logger.info("✅ Cleanup completed successfully")
    else:
        logger.warning("⚠️  Cleanup completed with warnings/errors")
        logger.info("Please review the output above for details")
    logger.info("=" * 60)

    return cleanup_successful


@click.command()
@click.option(
    '--state-file',
    required=True,
    type=click.Path(exists=True),
    help='Path to deployment state file (.test-state-*.yaml)'
)
@click.option(
    '--destroy-terraform',
    is_flag=True,
    help='Also run terraform destroy to remove infrastructure'
)
@click.option(
    '--auto-approve',
    is_flag=True,
    help='Auto-approve terraform destroy without prompting'
)
@click.option(
    '--config',
    default='config.yaml',
    type=click.Path(exists=True),
    help='Path to config file (default: config.yaml)'
)
def main(state_file, destroy_terraform, auto_approve, config):
    """
    Cleanup deployment artifacts from a test run.

    Removes DNS records, API resources, and optionally destroys
    terraform infrastructure. Deletes the state file when done.
    """
    try:
        success = cleanup_deployment(
            state_file=state_file,
            destroy_terraform=destroy_terraform,
            auto_approve=auto_approve,
            config_file=config
        )
        sys.exit(0 if success else 1)

    except KeyboardInterrupt:
        print("\nInterrupted by user")
        sys.exit(130)
    except Exception as e:
        print(f"Error: {e}")
        raise


if __name__ == '__main__':
    main()
