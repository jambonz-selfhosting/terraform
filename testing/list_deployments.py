#!/usr/bin/env python3
"""
List active test deployments.

Scans for deployment state files and displays a summary table
of all active test deployments.

Usage:
    python list_deployments.py
    python list_deployments.py --testing-dir /path/to/testing
"""

import sys
import click
from pathlib import Path
from datetime import datetime

# Add lib directory to path
sys.path.insert(0, str(Path(__file__).parent / "lib"))

from state_manager import list_deployments


@click.command()
@click.option(
    '--testing-dir',
    default='.',
    type=click.Path(exists=True),
    help='Directory to search for state files (default: current directory)'
)
def main(testing_dir):
    """
    List all active test deployments.

    Finds all .test-state-*.yaml files and displays their information
    in a formatted table.
    """
    try:
        deployments = list_deployments(testing_dir)

        if not deployments:
            print("No active test deployments found.")
            print("")
            print(f"Searched in: {Path(testing_dir).resolve()}")
            print("State files have pattern: .test-state-*.yaml")
            return

        print("")
        print("Active Test Deployments:")
        print("")

        # Table header
        header = f"{'Deployment ID':<35} {'Timestamp':<20} {'Provider':<12} {'Status':<10} {'Cleanup Command'}"
        print(header)
        print("─" * len(header))

        # Table rows
        for deployment in deployments:
            deployment_id = deployment.get('deployment_id', 'unknown')[:34]
            timestamp_str = deployment.get('timestamp', 'unknown')

            # Parse and format timestamp
            try:
                timestamp = datetime.fromisoformat(timestamp_str)
                timestamp_display = timestamp.strftime('%Y-%m-%d %H:%M:%S')
            except:
                timestamp_display = timestamp_str[:19]

            provider = deployment.get('provider', 'unknown')[:11]
            status = deployment.get('test_results', {}).get('status', 'unknown')[:9]
            state_file = deployment.get('_state_file', 'unknown')

            # Format status with color indicators
            if status == 'success':
                status_display = f"✓ {status}"
            elif status == 'failed':
                status_display = f"✗ {status}"
            else:
                status_display = f"  {status}"

            cleanup_cmd = f"cleanup_deployment.py --state-file {state_file}"

            print(f"{deployment_id:<35} {timestamp_display:<20} {provider:<12} {status_display:<10} {cleanup_cmd}")

        print("")
        print(f"Total: {len(deployments)} deployment(s)")
        print("")

        # Show additional details if requested
        print("For detailed information about a deployment:")
        print("  cat .test-state-<deployment-id>.yaml")
        print("")
        print("To cleanup a deployment:")
        print("  python cleanup_deployment.py --state-file .test-state-<deployment-id>.yaml")
        print("")

    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        raise


if __name__ == '__main__':
    main()
