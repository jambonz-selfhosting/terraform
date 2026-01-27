"""
SSH connection wrapper for remote command execution.

Supports both direct SSH connections and connections via jump hosts
for private instances (e.g., feature servers behind NAT).
"""

import paramiko
import logging
from typing import Tuple, Optional
from pathlib import Path


logger = logging.getLogger("jambonz-test")


class SSHError(Exception):
    """Raised when SSH operations fail."""
    pass


def run_ssh_command(
    host: str,
    command: str,
    ssh_config: dict,
    timeout: int = None,
    jump_host: str = None
) -> Tuple[str, str, int]:
    """
    Execute a command on a remote host via SSH.

    Args:
        host: Hostname or IP address
        command: Command to execute
        ssh_config: SSH configuration dict from config file (user, key_path, etc.)
        timeout: Command timeout in seconds (default: from ssh_config)
        jump_host: Optional jump host for private instances

    Returns:
        Tuple of (stdout, stderr, exit_code)

    Raises:
        SSHError: If SSH connection or command execution fails
    """
    if timeout is None:
        timeout = ssh_config.get('timeout', 300)

    user = ssh_config.get('user', 'jambonz')
    key_path = Path(ssh_config.get('key_path', '~/.ssh/id_rsa')).expanduser()
    strict_host_key_checking = ssh_config.get('strict_host_key_checking', False)

    if not key_path.exists():
        raise SSHError(f"SSH key not found: {key_path}")

    try:
        # Load SSH key
        private_key = paramiko.RSAKey.from_private_key_file(str(key_path))
    except Exception as e:
        raise SSHError(f"Failed to load SSH key from {key_path}: {e}")

    # Create SSH client
    client = paramiko.SSHClient()
    if not strict_host_key_checking:
        client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    else:
        client.load_system_host_keys()

    try:
        if jump_host:
            # Connect via jump host
            logger.debug(f"Connecting to {host} via jump host {jump_host}")
            stdout_str, stderr_str, exit_code = _run_via_jump_host(
                client, host, command, user, private_key, jump_host, timeout
            )
        else:
            # Direct connection
            logger.debug(f"Connecting directly to {host}")
            client.connect(
                hostname=host,
                username=user,
                pkey=private_key,
                timeout=30,
                banner_timeout=30
            )

            # Execute command
            stdin, stdout, stderr = client.exec_command(command, timeout=timeout)
            exit_code = stdout.channel.recv_exit_status()

            stdout_str = stdout.read().decode('utf-8')
            stderr_str = stderr.read().decode('utf-8')

        logger.debug(f"Command executed on {host}, exit code: {exit_code}")
        return stdout_str, stderr_str, exit_code

    except paramiko.AuthenticationException:
        raise SSHError(f"Authentication failed for {user}@{host}")
    except paramiko.SSHException as e:
        raise SSHError(f"SSH error connecting to {host}: {e}")
    except Exception as e:
        raise SSHError(f"Failed to execute command on {host}: {e}")
    finally:
        client.close()


def _run_via_jump_host(
    client: paramiko.SSHClient,
    target_host: str,
    command: str,
    user: str,
    private_key: paramiko.RSAKey,
    jump_host: str,
    timeout: int
) -> Tuple[str, str, int]:
    """
    Execute command on target host via jump host.

    Args:
        client: Paramiko SSH client
        target_host: Final destination host
        command: Command to execute
        user: SSH username
        private_key: SSH private key
        jump_host: Jump host address
        timeout: Command timeout in seconds

    Returns:
        Tuple of (stdout, stderr, exit_code)
    """
    # Connect to jump host
    client.connect(
        hostname=jump_host,
        username=user,
        pkey=private_key,
        timeout=30,
        banner_timeout=30
    )

    # Create transport to target through jump host
    transport = client.get_transport()
    dest_addr = (target_host, 22)
    local_addr = ('127.0.0.1', 22)
    channel = transport.open_channel("direct-tcpip", dest_addr, local_addr)

    # Connect to target via channel
    target_client = paramiko.SSHClient()
    target_client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    target_client.connect(
        hostname=target_host,
        username=user,
        pkey=private_key,
        sock=channel,
        timeout=30,
        banner_timeout=30
    )

    try:
        # Execute command on target
        stdin, stdout, stderr = target_client.exec_command(command, timeout=timeout)
        exit_code = stdout.channel.recv_exit_status()

        stdout_str = stdout.read().decode('utf-8')
        stderr_str = stderr.read().decode('utf-8')

        return stdout_str, stderr_str, exit_code
    finally:
        target_client.close()


def parse_ssh_command(ssh_cmd: str) -> dict:
    """
    Parse pre-formatted SSH command from terraform outputs.

    Terraform outputs provide SSH commands like:
    "ssh -i ~/.ssh/key jambonz@1.2.3.4"
    or with jump host:
    "ssh -i ~/.ssh/key -J jambonz@jump_ip jambonz@target_ip"

    Args:
        ssh_cmd: SSH command string from terraform

    Returns:
        Dictionary with parsed components: {
            'user': 'jambonz',
            'host': '1.2.3.4',
            'key_path': '~/.ssh/key',
            'jump_host': 'jump_ip' or None
        }
    """
    parts = ssh_cmd.split()

    parsed = {
        'user': None,
        'host': None,
        'key_path': None,
        'jump_host': None
    }

    # Extract key path (-i flag)
    if '-i' in parts:
        idx = parts.index('-i')
        if idx + 1 < len(parts):
            parsed['key_path'] = parts[idx + 1]

    # Extract jump host (-J flag)
    if '-J' in parts:
        idx = parts.index('-J')
        if idx + 1 < len(parts):
            jump_spec = parts[idx + 1]
            if '@' in jump_spec:
                parsed['jump_host'] = jump_spec.split('@')[1]
            else:
                parsed['jump_host'] = jump_spec

    # Extract user@host (last argument)
    if parts:
        target = parts[-1]
        if '@' in target:
            user, host = target.split('@', 1)
            parsed['user'] = user
            parsed['host'] = host
        else:
            parsed['host'] = target

    return parsed


def test_ssh_connectivity(host: str, ssh_config: dict, jump_host: str = None) -> bool:
    """
    Test SSH connectivity to a host.

    Args:
        host: Hostname or IP address
        ssh_config: SSH configuration dict
        jump_host: Optional jump host

    Returns:
        True if connection successful

    Raises:
        SSHError: If connection fails
    """
    try:
        stdout, stderr, exit_code = run_ssh_command(
            host=host,
            command="echo 'SSH connectivity test'",
            ssh_config=ssh_config,
            timeout=30,
            jump_host=jump_host
        )
        return exit_code == 0
    except SSHError:
        raise
