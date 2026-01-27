#!/usr/bin/env python3
"""
Cloud-init verification test for Jambonz Terraform deployments.

Tests deployed instances to verify cloud-init completed successfully
and all PM2 services are running.

Usage:
    # Test existing deployment:
    python test_cloud_init.py \\
        --terraform-dir ../exoscale/provision-vm-medium \\
        --config config.yaml

    # Deploy + test:
    python test_cloud_init.py \\
        --terraform-dir ../exoscale/provision-vm-medium \\
        --config config.yaml \\
        --deploy

    # Deploy + test + auto-cleanup on success:
    python test_cloud_init.py \\
        --terraform-dir ../exoscale/provision-vm-medium \\
        --config config.yaml \\
        --deploy \\
        --cleanup-on-success
"""

import sys
import time
import click
from pathlib import Path
from datetime import datetime

# Add lib directory to path
sys.path.insert(0, str(Path(__file__).parent / "lib"))

from config_loader import load_config
from logger import setup_logger
from terraform_helper import (
    terraform_apply,
    terraform_destroy,
    get_terraform_outputs,
    extract_provider_variant,
    set_terraform_env_vars,
    TerraformError
)
from state_manager import (
    create_deployment_state,
    save_state,
    add_artifact,
    update_test_results
)
from ssh_helper import parse_ssh_command, SSHError
from cloud_init_checker import verify_instance, CloudInitError


@click.command()
@click.option(
    '--terraform-dir',
    required=True,
    type=click.Path(exists=True),
    help='Path to terraform directory (e.g., ../exoscale/provision-vm-medium)'
)
@click.option(
    '--config',
    default='config.yaml',
    type=click.Path(exists=True),
    help='Path to config file (default: config.yaml)'
)
@click.option(
    '--deploy',
    is_flag=True,
    help='Run terraform apply before testing'
)
@click.option(
    '--cleanup-on-success',
    is_flag=True,
    help='Automatically cleanup deployment if all tests pass (requires --deploy)'
)
@click.option(
    '--var-file',
    type=click.Path(exists=True),
    help='Optional terraform vars file'
)
def main(terraform_dir, config, deploy, cleanup_on_success, var_file):
    """
    Test cloud-init completion and PM2 services on Jambonz deployment.
    """
    start_time = time.time()
    test_success = False
    state_file_path = None

    try:
        # Load configuration
        config_data = load_config(config)
        ssh_config = config_data.get('ssh', {})
        testing_config = config_data.get('testing', {})

        # Setup logging
        log_file = testing_config.get('log_file', './test-cloud-init.log')
        logger, log_file_path = setup_logger(log_file)

        logger.info("=" * 60)
        logger.info("Jambonz Cloud-Init Verification Test")
        logger.info("=" * 60)
        logger.info("")

        # Extract provider and variant
        provider, variant = extract_provider_variant(terraform_dir)
        logger.info(f"Provider: {provider}")
        logger.info(f"Variant: {variant}")
        logger.info(f"Terraform directory: {terraform_dir}")
        logger.info("")

        # Set terraform credentials from config
        try:
            set_terraform_env_vars(provider, config_data)
            logger.debug("Terraform credentials configured from config file")
        except TerraformError as e:
            logger.error(f"Failed to set terraform credentials: {e}")
            logger.error("Please ensure terraform credentials are configured in config.yaml")
            sys.exit(1)

        # Create deployment state
        state = create_deployment_state(
            terraform_dir=terraform_dir,
            provider=provider,
            variant=variant,
            applied_by_script=deploy
        )

        # Deploy if requested
        if deploy:
            logger.info("[Deployment Phase]")
            logger.info("Running terraform apply...")
            logger.info("")

            try:
                terraform_apply(terraform_dir, var_file=var_file, auto_approve=True)
                logger.info("✓ Terraform apply completed successfully")
                logger.info("")
            except TerraformError as e:
                logger.error(f"✗ Terraform apply failed: {e}")
                update_test_results(state, status='failed', step='terraform_apply')
                state_file_path = save_state(state)
                logger.info(f"State file saved: {state_file_path}")
                sys.exit(1)

            # Wait a moment for instances to initialize
            logger.info("Waiting 30 seconds for instances to initialize...")
            time.sleep(30)
            logger.info("")

        # Get terraform outputs
        logger.info("[Discovery Phase]")
        logger.info("Reading terraform outputs...")

        try:
            tf_outputs = get_terraform_outputs(terraform_dir)
            state['terraform']['outputs'] = tf_outputs
            logger.info(f"✓ Retrieved {len(tf_outputs)} terraform outputs")
            logger.debug(f"Outputs: {list(tf_outputs.keys())}")
        except TerraformError as e:
            logger.error(f"✗ Failed to get terraform outputs: {e}")
            update_test_results(state, status='failed', step='get_outputs')
            state_file_path = save_state(state)
            sys.exit(1)

        # Identify instances to test
        instances = _identify_instances(tf_outputs, logger)
        if not instances:
            logger.error("✗ No instances found in terraform outputs")
            update_test_results(state, status='failed', step='identify_instances')
            state_file_path = save_state(state)
            sys.exit(1)

        logger.info(f"✓ Found {len(instances)} instance(s) to verify")
        logger.info("")

        # Test each instance
        logger.info("[Verification Phase]")
        logger.info("Testing instances...")
        logger.info("")

        results = []
        failed_instances = []

        for instance in instances:
            role = instance['role']
            host = instance['host']
            jump_host = instance.get('jump_host')

            logger.info(f"Testing {role} ({host})...")
            if jump_host:
                logger.info(f"  (via jump host {jump_host})")

            try:
                result = verify_instance(
                    host=host,
                    ssh_config=ssh_config,
                    role=role,
                    jump_host=jump_host,
                    provider=provider
                )
                results.append(result)

                if result['success']:
                    logger.info(f"✓ {role}: All checks passed")
                else:
                    logger.warning(f"✗ {role}: Verification failed")
                    failed_instances.append(role)

            except (SSHError, CloudInitError) as e:
                logger.error(f"✗ {role}: {e}")
                failed_instances.append(role)
                results.append({
                    'role': role,
                    'host': host,
                    'success': False,
                    'error': str(e)
                })

            logger.info("")

        # Summary
        logger.info("=" * 60)
        if failed_instances:
            logger.error(f"✗ Test failed - {len(failed_instances)} instance(s) failed:")
            for role in failed_instances:
                logger.error(f"  - {role}")
            test_success = False
            update_test_results(state, status='failed', step='cloud_init_verification')
        else:
            logger.info(f"✅ All tests passed - {len(instances)} instance(s) verified")
            test_success = True
            update_test_results(state, status='success', step='cloud_init_verification')

        logger.info("=" * 60)
        logger.info("")

        # Calculate duration
        duration = time.time() - start_time
        update_test_results(state, status=state['test_results']['status'], duration=duration)

        # Print summary
        logger.info("Summary:")
        logger.info(f"  Total instances: {len(instances)}")
        logger.info(f"  Passed: {len([r for r in results if r.get('success')])}")
        logger.info(f"  Failed: {len(failed_instances)}")
        logger.info(f"  Duration: {duration:.1f} seconds")
        logger.info("")

        # Save state file
        state_file_path = save_state(state)
        logger.info(f"State file: {state_file_path}")
        logger.info(f"Log file: {log_file_path}")
        logger.info("")

        # Cleanup if requested and successful
        if cleanup_on_success and test_success and deploy:
            logger.info("[Cleanup Phase]")
            logger.info("Tests passed - running cleanup as requested...")
            logger.info("")

            from cleanup_deployment import cleanup_deployment
            cleanup_deployment(
                state_file=state_file_path,
                destroy_terraform=True,
                logger=logger
            )
        else:
            # Print cleanup instructions
            if not test_success:
                logger.info("Tests failed - deployment left running for debugging.")
            elif not cleanup_on_success:
                logger.info("Deployment left running.")

            logger.info("")
            logger.info("To cleanup this deployment later, run:")
            logger.info(f"  python cleanup_deployment.py --state-file {state_file_path}")
            if deploy:
                logger.info("")
                logger.info("To also destroy terraform resources:")
                logger.info(f"  python cleanup_deployment.py --state-file {state_file_path} --destroy-terraform")

        # Exit with appropriate code
        sys.exit(0 if test_success else 1)

    except KeyboardInterrupt:
        logger.info("")
        logger.info("Interrupted by user")
        if state_file_path:
            logger.info(f"State file: {state_file_path}")
        sys.exit(130)
    except Exception as e:
        logger.error(f"Unexpected error: {e}")
        if state_file_path:
            logger.info(f"State file: {state_file_path}")
        raise


def _identify_instances(tf_outputs: dict, logger) -> list:
    """
    Identify instances to test from terraform outputs.

    Args:
        tf_outputs: Terraform outputs dictionary
        logger: Logger instance

    Returns:
        List of instance dicts with keys: role, host, jump_host (optional)
    """
    instances = []

    # Strategy: Look for common output patterns
    # Terraform outputs may vary by provider/variant, so we try multiple patterns

    # Pattern 1: ssh_commands output (pre-formatted SSH commands)
    if 'ssh_commands' in tf_outputs:
        ssh_commands = tf_outputs['ssh_commands']
        if isinstance(ssh_commands, dict):
            for role, ssh_cmd in ssh_commands.items():
                parsed = parse_ssh_command(ssh_cmd)
                instances.append({
                    'role': role,
                    'host': parsed['host'],
                    'jump_host': parsed.get('jump_host')
                })
        logger.debug(f"Found {len(instances)} instances via ssh_commands output")

    # Pattern 2: Individual IP outputs (web_ip, sbc_ips, etc.)
    if not instances:
        # Look for web/monitoring instance
        for key in ['web_monitoring_public_ip', 'web_ip', 'monitoring_ip']:
            if key in tf_outputs:
                instances.append({
                    'role': 'web-monitoring',
                    'host': tf_outputs[key],
                    'jump_host': None
                })
                break

        # Look for SBC instances
        for key in ['sbc_public_ips', 'sbc_ips']:
            if key in tf_outputs:
                sbc_ips = tf_outputs[key]
                if isinstance(sbc_ips, list):
                    for i, ip in enumerate(sbc_ips):
                        instances.append({
                            'role': f'sbc-{i}',
                            'host': ip,
                            'jump_host': None
                        })
                elif isinstance(sbc_ips, str):
                    instances.append({
                        'role': 'sbc-0',
                        'host': sbc_ips,
                        'jump_host': None
                    })
                break

        # Look for feature server instances (usually private, need jump host)
        jump_host = None
        if instances and instances[0]['role'].startswith('sbc'):
            jump_host = instances[0]['host']  # Use first SBC as jump host

        for key in ['feature_server_private_ips', 'feature_ips']:
            if key in tf_outputs:
                feature_ips = tf_outputs[key]
                if isinstance(feature_ips, list):
                    for i, ip in enumerate(feature_ips):
                        instances.append({
                            'role': f'feature-server-{i}',
                            'host': ip,
                            'jump_host': jump_host
                        })
                elif isinstance(feature_ips, str):
                    instances.append({
                        'role': 'feature-server-0',
                        'host': feature_ips,
                        'jump_host': jump_host
                    })
                break

        logger.debug(f"Found {len(instances)} instances via individual IP outputs")

    return instances


if __name__ == '__main__':
    main()
