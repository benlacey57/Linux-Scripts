#!/usr/bin/env python3
"""
Tailscale Setup Script
Installs and configures Tailscale VPN
"""

import os
import sys
import json
import subprocess
import time
from pathlib import Path
from typing import Dict, Any, Optional, List


class TailscaleSetup:
    """Handles Tailscale installation and configuration."""
    
    def __init__(self, config_file: str = "settings.json"):
        self.config = self._load_config(config_file)
        self.tailscale_config = self.config.get('tailscale_config', {})
        self.network_config = self.config.get('network_config', {})
    
    def _load_config(self, config_file: str) -> Dict[str, Any]:
        """Load configuration from JSON file."""
        config_path = Path(config_file)
        
        if not config_path.exists():
            print(f"⚠ Configuration file not found: {config_file}")
            print(f"  Using default settings")
            return {}
        
        try:
            with open(config_path, 'r') as f:
                return json.load(f)
        except json.JSONDecodeError as e:
            print(f"⚠ Invalid JSON in configuration file: {e}")
            print(f"  Using default settings")
            return {}
    
    def check_root(self) -> bool:
        """Check if script is run as root."""
        if os.geteuid() != 0:
            print("✗ This script must be run as root")
            return False
        return True
    
    def is_installed(self) -> bool:
        """Check if Tailscale is already installed."""
        try:
            result = subprocess.run(
                ['which', 'tailscale'],
                capture_output=True,
                check=True
            )
            return True
        except subprocess.CalledProcessError:
            return False
    
    def install_tailscale(self) -> bool:
        """Install Tailscale."""
        print("\n📦 Installing Tailscale...")
        
        if self.is_installed():
            print("✓ Tailscale is already installed")
            
            # Check version
            try:
                result = subprocess.run(
                    ['tailscale', 'version'],
                    capture_output=True,
                    text=True,
                    check=True
                )
                print(f"  Version: {result.stdout.strip()}")
            except:
                pass
            
            return True
        
        try:
            # Download and run Tailscale install script
            print("  Downloading Tailscale installer...")
            
            curl_cmd = [
                'curl', '-fsSL',
                'https://tailscale.com/install.sh'
            ]
            
            result = subprocess.run(
                curl_cmd,
                capture_output=True,
                text=True,
                check=True
            )
            
            install_script = result.stdout
            
            print("  Running installer...")
            
            # Run the install script
            process = subprocess.Popen(
                ['sh'],
                stdin=subprocess.PIPE,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True
            )
            
            stdout, stderr = process.communicate(input=install_script)
            
            if process.returncode != 0:
                print(f"✗ Installation failed:")
                print(stderr)
                return False
            
            print("✓ Tailscale installed successfully")
            return True
            
        except subprocess.CalledProcessError as e:
            print(f"✗ Failed to install Tailscale: {e}")
            return False
        except Exception as e:
            print(f"✗ Unexpected error during installation: {e}")
            return False
    
    def is_logged_in(self) -> bool:
        """Check if Tailscale is authenticated."""
        try:
            result = subprocess.run(
                ['tailscale', 'status'],
                capture_output=True,
                text=True
            )
            
            # If we get output and no "not logged in" message
            if result.returncode == 0 and 'not logged in' not in result.stdout.lower():
                return True
            return False
            
        except Exception:
            return False
    
    def login_tailscale(self, args: Optional[List[str]] = None) -> bool:
        """Authenticate Tailscale."""
        print("\n🔐 Authenticating Tailscale...")
        
        if self.is_logged_in():
            print("✓ Already logged in")
            return True
        
        # Build login command with arguments
        cmd = ['tailscale', 'up']
        
        # Add configuration options
        if self.tailscale_config.get('accept_routes'):
            cmd.append('--accept-routes')
        
        if self.tailscale_config.get('accept_dns'):
            cmd.append('--accept-dns')
        
        if self.tailscale_config.get('shields_up'):
            cmd.append('--shields-up')
        
        if self.tailscale_config.get('advertise_exit_node'):
            cmd.append('--advertise-exit-node')
        
        if self.tailscale_config.get('ssh_enabled'):
            cmd.append('--ssh')
        
        hostname = self.tailscale_config.get('hostname', '')
        if hostname:
            cmd.extend(['--hostname', hostname])
        
        operator = self.tailscale_config.get('operator', '')
        if operator:
            cmd.extend(['--operator', operator])
        
        advertise_routes = self.tailscale_config.get('advertise_routes', [])
        if advertise_routes:
            routes = ','.join(advertise_routes)
            cmd.extend(['--advertise-routes', routes])
        
        # Add custom arguments if provided
        if args:
            cmd.extend(args)
        
        print(f"  Running: {' '.join(cmd)}")
        print("\n  ⚠ A browser window will open for authentication")
        print("  ⚠ Complete the authentication in your browser\n")
        
        try:
            result = subprocess.run(
                cmd,
                capture_output=False,  # Show output to user
                text=True
            )
            
            if result.returncode == 0:
                print("\n✓ Tailscale authenticated successfully")
                time.sleep(2)  # Give time for connection to establish
                return True
            else:
                print("\n✗ Authentication failed")
                return False
                
        except Exception as e:
            print(f"\n✗ Authentication error: {e}")
            return False
    
    def configure_exit_node(self) -> bool:
        """Configure exit node if specified."""
        exit_node = self.network_config.get('exit_node', '')
        
        if not exit_node:
            return True
        
        print(f"\n🌐 Configuring exit node: {exit_node}")
        
        cmd = ['tailscale', 'set', '--exit-node', exit_node]
        
        if self.network_config.get('exit_node_allow_lan_access'):
            cmd.append('--exit-node-allow-lan-access')
        
        try:
            subprocess.run(cmd, check=True, capture_output=True)
            print("✓ Exit node configured")
            return True
        except subprocess.CalledProcessError as e:
            print(f"✗ Failed to configure exit node: {e}")
            return False
    
    def enable_ip_forwarding(self) -> bool:
        """Enable IP forwarding (required for subnet routing and exit nodes)."""
        if not (self.tailscale_config.get('advertise_exit_node') or 
                self.tailscale_config.get('advertise_routes')):
            return True
        
        print("\n🔀 Enabling IP forwarding...")
        
        try:
            # Enable IPv4 forwarding
            if self.network_config.get('ipv4_enabled', True):
                subprocess.run(
                    ['sysctl', '-w', 'net.ipv4.ip_forward=1'],
                    check=True,
                    capture_output=True
                )
                print("✓ IPv4 forwarding enabled")
            
            # Enable IPv6 forwarding if requested
            if self.network_config.get('ipv6_enabled', False):
                subprocess.run(
                    ['sysctl', '-w', 'net.ipv6.conf.all.forwarding=1'],
                    check=True,
                    capture_output=True
                )
                print("✓ IPv6 forwarding enabled")
            
            # Make it persistent
            sysctl_conf = Path('/etc/sysctl.d/99-tailscale.conf')
            
            with open(sysctl_conf, 'w') as f:
                if self.network_config.get('ipv4_enabled', True):
                    f.write('net.ipv4.ip_forward = 1\n')
                if self.network_config.get('ipv6_enabled', False):
                    f.write('net.ipv6.conf.all.forwarding = 1\n')
            
            print(f"✓ IP forwarding persistence configured in {sysctl_conf}")
            return True
            
        except subprocess.CalledProcessError as e:
            print(f"✗ Failed to enable IP forwarding: {e}")
            return False
        except IOError as e:
            print(f"✗ Failed to write sysctl config: {e}")
            return False
    
    def show_status(self) -> bool:
        """Display Tailscale status."""
        print("\n📊 Tailscale Status...")
        
        try:
            result = subprocess.run(
                ['tailscale', 'status'],
                capture_output=True,
                text=True,
                check=True
            )
            
            print(result.stdout)
            return True
            
        except subprocess.CalledProcessError as e:
            print(f"✗ Failed to get status: {e}")
            return False
    
    def show_ip(self) -> bool:
        """Display Tailscale IP addresses."""
        print("\n🌐 Tailscale IP Addresses...")
        
        try:
            # IPv4
            result = subprocess.run(
                ['tailscale', 'ip', '-4'],
                capture_output=True,
                text=True,
                check=True
            )
            
            ipv4 = result.stdout.strip()
            if ipv4:
                print(f"  IPv4: {ipv4}")
            
            # IPv6
            result = subprocess.run(
                ['tailscale', 'ip', '-6'],
                capture_output=True,
                text=True,
                check=True
            )
            
            ipv6 = result.stdout.strip()
            if ipv6:
                print(f"  IPv6: {ipv6}")
            
            return True
            
        except subprocess.CalledProcessError as e:
            print(f"✗ Failed to get IP addresses: {e}")
            return False
    
    def verify_installation(self) -> bool:
        """Verify Tailscale is working correctly."""
        print("\n✅ Verifying installation...")
        
        checks = []
        
        # Check if installed
        if self.is_installed():
            print("✓ Tailscale binary installed")
            checks.append(True)
        else:
            print("✗ Tailscale binary not found")
            checks.append(False)
        
        # Check service status
        try:
            result = subprocess.run(
                ['systemctl', 'is-active', 'tailscaled'],
                capture_output=True,
                text=True
            )
            
            if result.stdout.strip() == 'active':
                print("✓ Tailscaled service is running")
                checks.append(True)
            else:
                print("✗ Tailscaled service is not running")
                checks.append(False)
        except:
            print("✗ Could not check service status")
            checks.append(False)
        
        # Check authentication
        if self.is_logged_in():
            print("✓ Tailscale is authenticated")
            checks.append(True)
        else:
            print("⚠ Tailscale is not authenticated")
            checks.append(False)
        
        return all(checks)
    
    def run(self) -> bool:
        """Run the complete setup process."""
        print("=" * 80)
        print("TAILSCALE SETUP".center(80))
        print("=" * 80)
        
        if not self.check_root():
            return False
        
        steps = [
            ("Installing Tailscale", self.install_tailscale),
            ("Enabling IP forwarding", self.enable_ip_forwarding),
            ("Authenticating Tailscale", self.login_tailscale),
            ("Configuring exit node", self.configure_exit_node),
            ("Verifying installation", self.verify_installation),
        ]
        
        for description, func in steps:
            if not func():
                print(f"\n⚠ Warning at step: {description}")
                
                if description == "Authenticating Tailscale":
                    print("\n  You can complete authentication later by running:")
                    print("  sudo tailscale up")
                    continue
                
                if description == "Configuring exit node":
                    continue  # Optional step
        
        self._print_summary()
        return True
    
    def _print_summary(self):
        """Print setup summary."""
        print("\n" + "=" * 80)
        print("SETUP COMPLETE".center(80))
        print("=" * 80)
        
        self.show_ip()
        print()
        self.show_status()
        
        print("\n📝 Configuration:")
        print(f"   Hostname: {self.tailscale_config.get('hostname', 'default')}")
        print(f"   Accept routes: {self.tailscale_config.get('accept_routes', False)}")
        print(f"   Accept DNS: {self.tailscale_config.get('accept_dns', False)}")
        print(f"   SSH enabled: {self.tailscale_config.get('ssh_enabled', False)}")
        print(f"   Exit node: {self.tailscale_config.get('advertise_exit_node', False)}")
        
        routes = self.tailscale_config.get('advertise_routes', [])
        if routes:
            print(f"   Advertised routes: {', '.join(routes)}")
        
        print("\n📋 Useful Commands:")
        print("   Show status:    tailscale status")
        print("   Show IP:        tailscale ip")
        print("   Show peers:     tailscale status --peers")
        print("   Logout:         sudo tailscale logout")
        print("   Debug:          sudo ./tailscale_debug.py")
        print("   View logs:      sudo ./tailscale_logs.py")
        
        print("\n🌐 Admin Console:")
        print("   https://login.tailscale.com/admin/machines")
        
        print("\n" + "=" * 80 + "\n")


def main():
    """Main execution function."""
    config_file = sys.argv[1] if len(sys.argv) > 1 else "settings.json"
    
    if len(sys.argv) > 1 and sys.argv[1] in ['-h', '--help']:
        print("Tailscale Setup Script")
        print("\nUsage:")
        print("  sudo ./tailscale_setup.py [config_file]")
        print("\nExamples:")
        print("  sudo ./tailscale_setup.py")
        print("  sudo ./tailscale_setup.py /path/to/settings.json")
        sys.exit(0)
    
    setup = TailscaleSetup(config_file)
    success = setup.run()
    
    sys.exit(0 if success else 1)


if __name__ == '__main__':
    main()
