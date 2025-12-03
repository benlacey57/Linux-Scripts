#!/usr/bin/env python3
"""
Tailscale Debug Script
Comprehensive diagnostics for Tailscale VPN issues
"""

import os
import sys
import subprocess
import json
import socket
from pathlib import Path
from typing import Dict, List, Tuple, Optional
from datetime import datetime


class TailscaleDebugger:
    """Diagnostic tool for Tailscale troubleshooting."""
    
    def __init__(self, config_file: str = "settings.json"):
        self.config = self._load_config(config_file)
        self.tailscale_config = self.config.get('tailscale_config', {})
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
    
    def check_installation(self):
        """Check if Tailscale is installed."""
        self.print_header("INSTALLATION CHECK")
        
        code, stdout, stderr = self._run_command(['which', 'tailscale'])
        
        if code == 0:
            print(f"✓ Tailscale binary found: {stdout.strip()}")
            self.passed_checks.append("Tailscale is installed")
            
            # Get version
            code, stdout, stderr = self._run_command(['tailscale', 'version'])
            if code == 0:
                print(f"  Version: {stdout.strip()}")
        else:
            print("✗ Tailscale is not installed")
            self.issues_found.append("Tailscale is not installed")
    
    def check_service(self):
        """Check Tailscale service status."""
        self.print_header("SERVICE STATUS")
        
        # Check if service is active
        code, stdout, stderr = self._run_command(['systemctl', 'is-active', 'tailscaled'])
        
        if stdout.strip() == 'active':
            print("✓ Tailscaled service: RUNNING")
            self.passed_checks.append("Tailscaled service is running")
        else:
            print("✗ Tailscaled service: NOT RUNNING")
            self.issues_found.append("Tailscaled service is not running")
            
            # Get service status
            code, stdout, stderr = self._run_command(['systemctl', 'status', 'tailscaled'])
            print(f"\n  Service status:\n{stdout[:500]}")
        
        # Check if enabled
        code, stdout, stderr = self._run_command(['systemctl', 'is-enabled', 'tailscaled'])
        
        if stdout.strip() == 'enabled':
            print("✓ Tailscaled service: ENABLED at boot")
        else:
            print("⚠ Tailscaled service: NOT ENABLED at boot")
            self.warnings.append("Tailscaled service not enabled at boot")
    
    def check_authentication(self):
        """Check if Tailscale is authenticated."""
        self.print_header("AUTHENTICATION STATUS")
        
        code, stdout, stderr = self._run_command(['tailscale', 'status'])
        
        if code == 0:
            if 'not logged in' in stdout.lower() or 'logged out' in stdout.lower():
                print("✗ Tailscale: NOT AUTHENTICATED")
                self.issues_found.append("Tailscale is not authenticated")
                print("\n  To authenticate, run: sudo tailscale up")
            else:
                print("✓ Tailscale: AUTHENTICATED")
                self.passed_checks.append("Tailscale is authenticated")
        else:
            print("✗ Could not check authentication status")
            self.issues_found.append("Cannot check authentication status")
    
    def check_connectivity(self):
        """Check Tailscale connectivity and peers."""
        self.print_header("CONNECTIVITY STATUS")
        
        # Get status with peers
        code, stdout, stderr = self._run_command(['tailscale', 'status'])
        
        if code != 0:
            print("✗ Could not get Tailscale status")
            return
        
        lines = stdout.strip().split('\n')
        
        if len(lines) <= 1:
            print("⚠ No peers found")
            self.warnings.append("No Tailscale peers connected")
            return
        
        print(f"✓ Connected to {len(lines) - 1} peer(s)\n")
        
        # Show peer details
        for line in lines[:10]:  # Show first 10 peers
            print(f"  {line}")
        
        if len(lines) > 10:
            print(f"\n  ... and {len(lines) - 10} more peer(s)")
        
        self.passed_checks.append(f"Connected to {len(lines) - 1} peers")
    
    def check_ip_addresses(self):
        """Check Tailscale IP addresses."""
        self.print_header("IP ADDRESS CHECK")
        
        # IPv4
        code, stdout, stderr = self._run_command(['tailscale', 'ip', '-4'])
        
        if code == 0 and stdout.strip():
            ipv4 = stdout.strip()
            print(f"✓ IPv4 address: {ipv4}")
            self.passed_checks.append(f"Has IPv4 address: {ipv4}")
        else:
            print("✗ No IPv4 address assigned")
            self.issues_found.append("No IPv4 address")
        
        # IPv6
        code, stdout, stderr = self._run_command(['tailscale', 'ip', '-6'])
        
        if code == 0 and stdout.strip():
            ipv6 = stdout.strip()
            print(f"✓ IPv6 address: {ipv6}")
        else:
            print("⚠ No IPv6 address assigned")
    
    def check_routes(self):
        """Check advertised and accepted routes."""
        self.print_header("ROUTE CONFIGURATION")
        
        # Check advertised routes
        advertised = self.tailscale_config.get('advertise_routes', [])
        if advertised:
            print(f"Configured advertised routes: {', '.join(advertised)}")
        else:
            print("No routes configured for advertisement")
        
        # Check if accepting routes
        accept_routes = self.tailscale_config.get('accept_routes', False)
        print(f"\nAccepting routes: {'Enabled' if accept_routes else 'Disabled'}")
        
        # Get actual routes from status
        code, stdout, stderr = self._run_command(['tailscale', 'status', '--json'])
        
        if code == 0:
            try:
                status = json.loads(stdout)
                
                # Check for approved routes
                if 'Self' in status and 'AllowedIPs' in status['Self']:
                    allowed = status['Self']['AllowedIPs']
                    if allowed:
                        print(f"\nAllowed IPs: {', '.join(allowed)}")
            except json.JSONDecodeError:
                pass
    
    def check_exit_node(self):
        """Check exit node configuration."""
        self.print_header("EXIT NODE STATUS")
        
        configured_exit = self.config.get('network_config', {}).get('exit_node', '')
        
        if configured_exit:
            print(f"Configured exit node: {configured_exit}")
        
        # Check if advertising as exit node
        if self.tailscale_config.get('advertise_exit_node', False):
            print("✓ Advertising as exit node")
            
            # Check IP forwarding
            code, stdout, stderr = self._run_command(['sysctl', 'net.ipv4.ip_forward'])
            
            if '= 1' in stdout:
                print("✓ IP forwarding enabled")
            else:
                print("✗ IP forwarding disabled")
                self.issues_found.append("IP forwarding disabled (required for exit node)")
        else:
            print("Not advertising as exit node")
        
        # Check current exit node in use
        code, stdout, stderr = self._run_command(['tailscale', 'status', '--json'])
        
        if code == 0:
            try:
                status = json.loads(stdout)
                
                if 'ExitNodeStatus' in status and status['ExitNodeStatus']:
                    exit_status = status['ExitNodeStatus']
                    if exit_status.get('Online'):
                        print(f"\n✓ Using exit node: {exit_status.get('TailscaleIPs', ['Unknown'])[0]}")
                    else:
                        print(f"\n⚠ Exit node offline")
            except json.JSONDecodeError:
                pass
    
    def check_dns(self):
        """Check DNS configuration."""
        self.print_header("DNS CONFIGURATION")
        
        accept_dns = self.tailscale_config.get('accept_dns', True)
        print(f"Accepting DNS: {'Enabled' if accept_dns else 'Disabled'}")
        
        # Check MagicDNS status
        code, stdout, stderr = self._run_command(['tailscale', 'status', '--json'])
        
        if code == 0:
            try:
                status = json.loads(stdout)
                
                if 'MagicDNSSuffix' in status:
                    suffix = status['MagicDNSSuffix']
                    print(f"✓ MagicDNS suffix: {suffix}")
                    self.passed_checks.append(f"MagicDNS enabled: {suffix}")
                else:
                    print("⚠ MagicDNS not configured")
            except json.JSONDecodeError:
                pass
        
        # Check resolv.conf
        resolv_conf = Path('/etc/resolv.conf')
        
        if resolv_conf.exists():
            with open(resolv_conf, 'r') as f:
                content = f.read()
            
            if '100.100.100.100' in content:
                print("✓ Tailscale DNS configured in /etc/resolv.conf")
            else:
                print("⚠ Tailscale DNS not in /etc/resolv.conf")
    
    def check_ssh(self):
        """Check Tailscale SSH configuration."""
        self.print_header("SSH CONFIGURATION")
        
        if self.tailscale_config.get('ssh_enabled', False):
            print("✓ Tailscale SSH enabled in config")
            print("\n  Connect from other devices: ssh user@hostname")
            print("  (hostname is the Tailscale machine name)")
        else:
            print("⚠ Tailscale SSH not enabled")
    
    def check_firewall(self):
        """Check firewall configuration."""
        self.print_header("FIREWALL STATUS")
        
        # Check UFW
        code, stdout, stderr = self._run_command(['which', 'ufw'])
        
        if code == 0:
            code, stdout, stderr = self._run_command(['ufw', 'status'])
            
            if 'inactive' in stdout.lower():
                print("✓ UFW is inactive (Tailscale doesn't require firewall rules)")
            else:
                print("UFW is active")
                
                if 'tailscale' in stdout.lower() or '41641' in stdout:
                    print("✓ Tailscale port allowed")
                else:
                    print("⚠ Tailscale port (41641/udp) not explicitly allowed")
                    print("  (This is usually fine - Tailscale can work without explicit rules)")
        else:
            print("⚠ UFW not installed")
    
    def test_connectivity(self):
        """Test connectivity to Tailscale coordination server."""
        self.print_header("CONNECTIVITY TEST")
        
        print("Testing connection to Tailscale coordination server...")
        
        # Test DNS resolution
        try:
            socket.gethostbyname('controlplane.tailscale.com')
            print("✓ Can resolve controlplane.tailscale.com")
        except socket.gaierror:
            print("✗ Cannot resolve controlplane.tailscale.com")
            self.issues_found.append("Cannot resolve Tailscale coordination server")
        
        # Test HTTPS connectivity
        code, stdout, stderr = self._run_command(
            ['curl', '-s', '-o', '/dev/null', '-w', '%{http_code}', 
             'https://controlplane.tailscale.com', '--max-time', '5']
        )
        
        if code == 0 and '200' in stdout:
            print("✓ Can reach controlplane.tailscale.com via HTTPS")
        else:
            print("✗ Cannot reach controlplane.tailscale.com")
            self.issues_found.append("Cannot reach Tailscale coordination server")
    
    def check_logs(self):
        """Check for errors in logs."""
        self.print_header("LOG ANALYSIS")
        
        # Check journalctl for tailscaled
        code, stdout, stderr = self._run_command(
            ['journalctl', '-u', 'tailscaled', '-n', '50', '--no-pager']
        )
        
        if code == 0:
            lines = stdout.strip().split('\n')
            
            error_count = 0
            for line in lines:
                if any(word in line.lower() for word in ['error', 'fail', 'warning']):
                    error_count += 1
            
            if error_count > 0:
                print(f"⚠ Found {error_count} error/warning entries in recent logs")
                print(f"  Run: sudo journalctl -u tailscaled -f")
            else:
                print("✓ No obvious errors in recent logs")
        else:
            print("⚠ Could not read logs")
    
    def generate_fixes(self):
        """Generate suggested fixes for found issues."""
        if not self.issues_found:
            return
        
        self.print_header("SUGGESTED FIXES")
        
        for i, issue in enumerate(self.issues_found, 1):
            print(f"{i}. {issue}")
            
            if 'not installed' in issue.lower():
                print(f"   Fix: sudo ./tailscale_setup.py")
            
            elif 'service is not running' in issue.lower():
                print(f"   Fix: sudo systemctl start tailscaled")
                print(f"        sudo systemctl enable tailscaled")
            
            elif 'not authenticated' in issue.lower():
                print(f"   Fix: sudo tailscale up")
            
            elif 'no ipv4 address' in issue.lower():
                print(f"   Fix: Check authentication and connection")
                print(f"        sudo tailscale status")
            
            elif 'ip forwarding' in issue.lower():
                print(f"   Fix: sudo sysctl -w net.ipv4.ip_forward=1")
                print(f"        echo 'net.ipv4.ip_forward = 1' | sudo tee /etc/sysctl.d/99-tailscale.conf")
            
            elif 'cannot reach' in issue.lower():
                print(f"   Fix: Check internet connectivity")
                print(f"        Check firewall settings")
                print(f"        Verify no proxy blocking connections")
            
            print()

      def run_diagnostics(self):
        """Run all diagnostic checks."""
        print("\n" + "=" * 80)
        print("TAILSCALE DIAGNOSTICS".center(80))
        print(f"{'Started: ' + datetime.now().strftime('%Y-%m-%d %H:%M:%S')}".center(80))
        print("=" * 80)
        
        # Run all checks
        self.check_installation()
        self.check_service()
        self.check_authentication()
        self.check_ip_addresses()
        self.check_connectivity()
        self.check_routes()
        self.check_exit_node()
        self.check_dns()
        self.check_ssh()
        self.check_firewall()
        self.test_connectivity()
        self.check_logs()
        
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
            print("  1. Check your Tailscale admin console: https://login.tailscale.com/admin/machines")
            print("  2. Review logs: sudo journalctl -u tailscaled -f")
            print("  3. Try restarting: sudo systemctl restart tailscaled")
        
        print("\n" + "=" * 80 + "\n")


def main():
    """Main execution function."""
    config_file = "settings.json"
    
    if len(sys.argv) > 1:
        if sys.argv[1] in ['-h', '--help']:
            print("Tailscale Debug Script")
            print("\nUsage:")
            print("  sudo ./tailscale_debug.py [config_file]")
            print("\nExamples:")
            print("  sudo ./tailscale_debug.py")
            print("  sudo ./tailscale_debug.py /path/to/settings.json")
            sys.exit(0)
        
        config_file = sys.argv[1]
    
    debugger = TailscaleDebugger(config_file)
    debugger.run_diagnostics()


if __name__ == '__main__':
    main()
