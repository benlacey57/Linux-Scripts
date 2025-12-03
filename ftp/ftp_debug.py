#!/usr/bin/env python3
"""
FTP Server Debug Script
Comprehensive diagnostics for FTP/SFTP server issues
"""

import os
import sys
import subprocess
import json
from pathlib import Path
from typing import Dict, List, Tuple, Optional
from datetime import datetime


class FTPDebugger:
    """Diagnostic tool for FTP server troubleshooting."""
    
    def __init__(self, config_file: str = "settings.json"):
        self.config = self._load_config(config_file)
        self.ftp_config = self.config.get('ftp_config', {})
        self.issues_found = []
        self.warnings = []
        self.passed_checks = []
    
    def _load_config(self, config_file: str) -> Dict:
        """Load configuration file."""
        config_path = Path(config_file)
        
        if not config_path.exists():
            return {}
        
        try:
            with open(config_path, 'r') as f:
                return json.load(f)
        except:
            return {}
    
    def _run_command(self, cmd: List[str], timeout: int = 10) -> Tuple[int, str, str]:
        """Run a command and return exit code, stdout, stderr."""
        try:
            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                timeout=timeout
            )
            return result.returncode, result.stdout, result.stderr
        except subprocess.TimeoutExpired:
            return -1, "", "Command timed out"
        except Exception as e:
            return -1, "", str(e)
    
    def print_header(self, title: str):
        """Print formatted section header."""
        print(f"\n{'=' * 80}")
        print(f"{title.center(80)}")
        print(f"{'=' * 80}\n")
    
    def check_services(self):
        """Check if FTP services are running."""
        self.print_header("SERVICE STATUS")
        
        services = {
            'vsftpd': 'vsftpd (FTP Server)',
            'ssh': 'SSH/SFTP Server',
            'fail2ban': 'fail2ban (optional)'
        }
        
        for service, description in services.items():
            code, stdout, stderr = self._run_command(['systemctl', 'is-active', service])
            
            if stdout.strip() == 'active':
                print(f"✓ {description}: RUNNING")
                self.passed_checks.append(f"{description} is running")
            elif service == 'fail2ban':
                print(f"⚠ {description}: NOT RUNNING (optional)")
                self.warnings.append(f"{description} is not running")
            else:
                print(f"✗ {description}: NOT RUNNING")
                self.issues_found.append(f"{description} is not running")
                
                # Get detailed status
                code, stdout, stderr = self._run_command(['systemctl', 'status', service])
                print(f"   Status output:\n{stdout[:500]}")
    
    def check_ports(self):
        """Check if FTP ports are listening."""
        self.print_header("PORT LISTENING STATUS")
        
        ports = {
            '21': 'FTP Control',
            '22': 'SSH/SFTP',
            '20': 'FTP Data (may not always show)'
        }
        
        code, stdout, stderr = self._run_command(['netstat', '-tuln'])
        
        if code != 0:
            code, stdout, stderr = self._run_command(['ss', '-tuln'])
        
        for port, description in ports.items():
            if f':{port}' in stdout:
                print(f"✓ Port {port} ({description}): LISTENING")
                self.passed_checks.append(f"Port {port} is listening")
            else:
                if port == '20':
                    print(f"⚠ Port {port} ({description}): NOT LISTENING (may be normal)")
                    self.warnings.append(f"Port {port} not listening")
                else:
                    print(f"✗ Port {port} ({description}): NOT LISTENING")
                    self.issues_found.append(f"Port {port} is not listening")
    
    def check_firewall(self):
        """Check firewall configuration."""
        self.print_header("FIREWALL STATUS")
        
        # Check if UFW is installed
        code, stdout, stderr = self._run_command(['which', 'ufw'])
        
        if code != 0:
            print("⚠ UFW not installed")
            self.warnings.append("UFW firewall not installed")
            return
        
        # Check UFW status
        code, stdout, stderr = self._run_command(['ufw', 'status'])
        
        if 'inactive' in stdout.lower():
            print("⚠ UFW is inactive")
            self.warnings.append("UFW firewall is inactive")
            return
        
        print("✓ UFW is active\n")
        
        # Check required ports
        required_ports = ['21', '22', '40000:40100']
        
        for port in required_ports:
            if port in stdout:
                print(f"✓ Port {port}: ALLOWED")
                self.passed_checks.append(f"Firewall allows port {port}")
            else:
                print(f"✗ Port {port}: NOT ALLOWED")
                self.issues_found.append(f"Firewall does not allow port {port}")
    
    def check_configuration(self):
        """Check vsftpd configuration."""
        self.print_header("CONFIGURATION CHECKS")
        
        config_file = Path('/etc/vsftpd.conf')
        
        if not config_file.exists():
            print("✗ vsftpd.conf not found")
            self.issues_found.append("vsftpd.conf file missing")
            return
        
        print(f"✓ Configuration file exists: {config_file}\n")
        
        with open(config_file, 'r') as f:
            config_content = f.read()
        
        # Critical settings to check
        critical_settings = {
            'listen=YES': 'IPv4 listening',
            'local_enable=YES': 'Local users enabled',
            'write_enable=YES': 'Write permissions',
            'pasv_enable=YES': 'Passive mode',
            'userlist_enable=YES': 'User list enabled',
            'chroot_local_user=NO': 'Chroot disabled (correct for this setup)'
        }
        
        for setting, description in critical_settings.items():
            if setting in config_content:
                print(f"✓ {description}: {setting}")
                self.passed_checks.append(f"Config has {description}")
            else:
                print(f"✗ {description}: NOT FOUND ({setting})")
                self.issues_found.append(f"Config missing {description}")
        
        # Check for potential issues
        if 'listen_ipv6=YES' in config_content and 'listen=YES' in config_content:
            print("\n✗ WARNING: Both IPv4 and IPv6 listen enabled (conflict)")
            self.issues_found.append("IPv4 and IPv6 both enabled")
        
        if 'chroot_local_user=YES' in config_content:
            print("\n⚠ WARNING: chroot is enabled - this may cause issues with the current setup")
            self.warnings.append("Chroot enabled (should be disabled)")
    
    def check_user_list(self):
        """Check FTP user list configuration."""
        self.print_header("USER LIST CHECKS")
        
        userlist_file = Path(self.ftp_config.get('allowed_users_file', '/etc/vsftpd.userlist'))
        
        if not userlist_file.exists():
            print(f"⚠ User list file not found: {userlist_file}")
            self.warnings.append("User list file does not exist")
            return
        
        print(f"✓ User list file exists: {userlist_file}\n")
        
        with open(userlist_file, 'r') as f:
            users = [line.strip() for line in f if line.strip() and not line.startswith('#')]
        
        if not users:
            print("⚠ No users defined in user list")
            self.warnings.append("User list is empty")
            return
        
        print(f"Found {len(users)} user(s) in list:\n")
        
        for username in users:
            # Check if user exists
            code, stdout, stderr = self._run_command(['id', username])
            
            if code == 0:
                print(f"✓ User '{username}' exists")
                
                # Check user's directory
                ftp_root = Path(self.ftp_config.get('ftp_root', '/srv/ftp'))
                user_dir = ftp_root / username
                
                if user_dir.exists():
                    print(f"  ✓ Directory: {user_dir}")
                    
                    # Check permissions
                    stat = user_dir.stat()
                    mode = oct(stat.st_mode)[-3:]
                    
                    # Get expected UID
                    import pwd
                    try:
                        user_info = pwd.getpwnam(username)
                        expected_uid = user_info.pw_uid
                        
                        if stat.st_uid == expected_uid:
                            print(f"  ✓ Owned by user (UID {stat.st_uid})")
                        else:
                            print(f"  ⚠ Owned by UID {stat.st_uid}, expected {expected_uid}")
                            self.warnings.append(f"User {username} directory ownership mismatch")
                        
                        print(f"  Permissions: {mode}")
                    except KeyError:
                        print(f"  ⚠ Could not verify ownership")
                else:
                    print(f"  ✗ Directory missing: {user_dir}")
                    self.issues_found.append(f"User {username} directory missing")
            else:
                print(f"✗ User '{username}' does not exist in system")
                self.issues_found.append(f"User {username} in list but not in system")
            
            print()
    
    def check_permissions(self):
        """Check critical directory permissions."""
        self.print_header("PERMISSION CHECKS")
        
        ftp_root = Path(self.ftp_config.get('ftp_root', '/srv/ftp'))
        
        if not ftp_root.exists():
            print(f"✗ FTP root does not exist: {ftp_root}")
            self.issues_found.append("FTP root directory missing")
            return
        
        print(f"✓ FTP root exists: {ftp_root}")
        
        stat = ftp_root.stat()
        mode = oct(stat.st_mode)[-3:]
        
        print(f"  Permissions: {mode}")
        print(f"  Owner: UID {stat.st_uid}")
        
        if stat.st_uid == 0:
            print(f"  ✓ Owned by root")
            self.passed_checks.append("FTP root owned by root")
        else:
            print(f"  ⚠ Not owned by root")
            self.warnings.append("FTP root not owned by root")
        
        # Check user directories
        print(f"\nChecking user directories...")
        userlist_file = Path(self.ftp_config.get('allowed_users_file', '/etc/vsftpd.userlist'))
        
        if userlist_file.exists():
            with open(userlist_file, 'r') as f:
                users = [line.strip() for line in f if line.strip() and not line.startswith('#')]
            
            for username in users[:5]:  # Check first 5 users
                user_dir = ftp_root / username
                if user_dir.exists():
                    stat = user_dir.stat()
                    print(f"  {username}: UID {stat.st_uid}, Permissions {oct(stat.st_mode)[-3:]}")
    
    def check_logs(self):
        """Check FTP logs for recent errors."""
        self.print_header("LOG FILE ANALYSIS")
        
        log_files = [
            '/var/log/vsftpd.log',
            '/var/log/syslog',
            '/var/log/auth.log'
        ]
        
        for log_file in log_files:
            log_path = Path(log_file)
            
            if not log_path.exists():
                print(f"⚠ Log file not found: {log_file}")
                continue
            
            print(f"\n📄 Checking {log_file}...")
            
            # Get last 20 lines with 'vsftpd' or 'ftp'
            code, stdout, stderr = self._run_command(
                ['grep', '-i', 'vsftpd\\|ftp', log_file]
            )
            
            if stdout:
                lines = stdout.strip().split('\n')
                recent_lines = lines[-20:] if len(lines) > 20 else lines
                
                error_count = 0
                for line in recent_lines:
                    if any(word in line.lower() for word in ['error', 'fail', 'denied', 'refused']):
                        error_count += 1
                
                if error_count > 0:
                    print(f"  ⚠ Found {error_count} error/warning entries in recent logs")
                    print(f"  Run: sudo tail -50 {log_file} | grep -i error")
                else:
                    print(f"  ✓ No obvious errors in recent logs")
    
    def check_network(self):
        """Check network connectivity."""
        self.print_header("NETWORK CHECKS")
        
        # Get server IP addresses
        code, stdout, stderr = self._run_command(['hostname', '-I'])
        
        if code == 0:
            ips = stdout.strip().split()
            print(f"✓ Server IP addresses:")
            for ip in ips:
                print(f"  - {ip}")
            print()
        
        # Check if server is reachable on port 21
        code, stdout, stderr = self._run_command(['nc', '-zv', 'localhost', '21'])
        
        if code == 0 or 'succeeded' in stdout.lower() or 'succeeded' in stderr.lower():
            print("✓ Port 21 is reachable on localhost")
            self.passed_checks.append("Port 21 reachable on localhost")
        else:
            print("✗ Port 21 is NOT reachable on localhost")
            self.issues_found.append("Port 21 not reachable")
    
    def test_ftp_connection(self, username: Optional[str] = None):
        """Test FTP connection."""
        if not username:
            return
        
        self.print_header(f"CONNECTION TEST FOR USER: {username}")
        
        print("Testing FTP connection...")
        print("Note: This requires the user's password\n")
        
        print("To test manually, run:")
        print(f"  ftp localhost")
        print(f"  Username: {username}")
        print(f"  Password: <enter password>")
        print(f"  Commands: ls, pwd, quit")
    
    def generate_fixes(self):
        """Generate suggested fixes for found issues."""
        if not self.issues_found:
            return
        
        self.print_header("SUGGESTED FIXES")
        
        for i, issue in enumerate(self.issues_found, 1):
            print(f"{i}. {issue}")
            
            # Provide specific fix suggestions
            if 'not running' in issue.lower():
                service = issue.split()[0].lower()
                print(f"   Fix: sudo systemctl start {service}")
                print(f"        sudo systemctl enable {service}")
            
            elif 'port' in issue.lower() and 'listening' in issue.lower():
                print(f"   Fix: Check if service is running")
                print(f"        Check /etc/vsftpd.conf for listen settings")
            
            elif 'firewall' in issue.lower():
                port = issue.split()[3] if len(issue.split()) > 3 else 'PORT'
                print(f"   Fix: sudo ufw allow {port}")
            
            elif 'directory missing' in issue.lower():
                username = issue.split()[1]
                ftp_root = self.ftp_config.get('ftp_root', '/srv/ftp')
                print(f"   Fix: sudo mkdir -p {ftp_root}/{username}")
                print(f"        sudo chown {username}:ftpusers {ftp_root}/{username}")
                print(f"        sudo chmod 755 {ftp_root}/{username}")
            
            elif 'ownership mismatch' in issue.lower():
                username = issue.split()[1]
                ftp_root = self.ftp_config.get('ftp_root', '/srv/ftp')
                print(f"   Fix: sudo chown {username}:ftpusers {ftp_root}/{username}")
            
            print()

    def run_diagnostics(self, username: Optional[str] = None):
        """Run all diagnostic checks."""
        print("\n" + "=" * 80)
        print("FTP SERVER DIAGNOSTICS".center(80))
        print(f"{'Started: ' + datetime.now().strftime('%Y-%m-%d %H:%M:%S')}".center(80))
        print("=" * 80)
        
        # Run all checks
        self.check_services()
        self.check_ports()
        self.check_firewall()
        self.check_configuration()
        self.check_user_list()
        self.check_permissions()
        self.check_network()
        self.check_logs()
        
        if username:
            self.test_ftp_connection(username)
        
        # Print summary
        self.print_header("DIAGNOSTIC SUMMARY")
        
        total_checks = len(self.passed_checks) + len(self.warnings) + len(self.issues_found)
        
        print(f"Total Checks: {total_checks}")
        print(f"✓ Passed: {len(self.passed_checks)}")
        print(f"⚠ Warnings: {len(self.warnings)}")
        print(f"✗ Issues: {len(self.issues_found)}\n")
        
        if self.warnings:
            print("Warnings:")
            for warning in self.warnings:
                print(f"  ⚠ {warning}")
            print()
        
        if self.issues_found:
            print("Critical Issues Found:")
            for issue in self.issues_found:
                print(f"  ✗ {issue}")
            print()
            
            self.generate_fixes()
        else:
            print("✓ No critical issues found!")
            print("\nIf you're still experiencing problems:")
            print("  1. Check firewall rules on router/network")
            print("  2. Verify user passwords are correct")
            print("  3. Review logs: sudo tail -f /var/log/vsftpd.log")
        
        print("\n" + "=" * 80 + "\n")


def main():
    """Main execution function."""
    config_file = "settings.json"
    username = None
    
    if len(sys.argv) > 1:
        if sys.argv[1] in ['-h', '--help']:
            print("Usage: ./ftp_debug.py [config_file] [username]")
            print("\nExamples:")
            print("  ./ftp_debug.py")
            print("  ./ftp_debug.py settings.json")
            print("  ./ftp_debug.py settings.json testuser")
            sys.exit(0)
        
        config_file = sys.argv[1]
        
        if len(sys.argv) > 2:
            username = sys.argv[2]
    
    debugger = FTPDebugger(config_file)
    debugger.run_diagnostics(username)


if __name__ == '__main__':
    main()
