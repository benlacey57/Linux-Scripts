#!/usr/bin/env python3
"""
Tailscale Log Viewer
Interactive viewer for Tailscale logs
"""

import os
import sys
import subprocess
from pathlib import Path
from typing import Optional


class TailscaleLogViewer:
    """Interactive Tailscale log viewer."""
    
    def __init__(self):
        self.log_sources = {
            '1': ('journalctl -u tailscaled', 'Tailscaled service logs'),
            '2': ('/var/log/syslog', 'System log (Tailscale entries)'),
            '3': ('/var/log/tailscale', 'Tailscale log directory'),
        }
    
    def check_root(self) -> bool:
        """Check if running as root."""
        if os.geteuid() != 0:
            print("⚠ Some log files may require root access")
            print("  Run with: sudo ./tailscale_logs.py")
            return False
        return True
    
    def view_journal_logs(self, filter_term: Optional[str] = None, 
                          lines: int = 50, follow: bool = False):
        """View logs from journalctl."""
        print(f"\n{'=' * 80}")
        print("TAILSCALED SERVICE LOGS".center(80))
        if filter_term:
            print(f"FILTER: {filter_term}".center(80))
        print(f"{'=' * 80}\n")
        
        cmd = ['journalctl', '-u', 'tailscaled', '--no-pager']
        
        if follow:
            cmd.append('-f')
        else:
            cmd.extend(['-n', str(lines)])
        
        try:
            if follow:
                if filter_term:
                    journal_proc = subprocess.Popen(cmd, stdout=subprocess.PIPE)
                    grep_proc = subprocess.Popen(
                        ['grep', '--line-buffered', '-i', filter_term],
                        stdin=journal_proc.stdout,
                        stdout=sys.stdout
                    )
                    grep_proc.communicate()
                else:
                    subprocess.run(cmd)
            else:
                if filter_term:
                    result = subprocess.run(cmd, capture_output=True, text=True)
                    for line in result.stdout.split('\n'):
                        if filter_term.lower() in line.lower():
                            print(line)
                else:
                    subprocess.run(cmd)
            
            return True
        except KeyboardInterrupt:
            print("\n\nStopped viewing logs")
            return True
        except Exception as e:
            print(f"✗ Error reading logs: {e}")
            return False
    
    def view_file_logs(self, log_file: str, filter_term: Optional[str] = None,
                       lines: int = 50, follow: bool = False):
        """View logs from a file."""
        log_path = Path(log_file)
        
        if not log_path.exists():
            print(f"✗ Log file not found: {log_file}")
            return False
        
        print(f"\n{'=' * 80}")
        print(f"LOG: {log_file}".center(80))
        if filter_term:
            print(f"FILTER: {filter_term}".center(80))
        print(f"{'=' * 80}\n")
        
        try:
            if follow:
                cmd = ['tail', '-f', log_file]
                if filter_term:
                    tail_proc = subprocess.Popen(cmd, stdout=subprocess.PIPE)
                    grep_proc = subprocess.Popen(
                        ['grep', '--line-buffered', '-i', filter_term],
                        stdin=tail_proc.stdout,
                        stdout=sys.stdout
                    )
                    grep_proc.communicate()
                else:
                    subprocess.run(cmd)
            else:
                if filter_term:
                    cmd = f"tail -{lines} {log_file} | grep -i '{filter_term}'"
                    subprocess.run(cmd, shell=True)
                else:
                    subprocess.run(['tail', f'-{lines}', log_file])
            
            return True
        except KeyboardInterrupt:
            print("\n\nStopped viewing logs")
            return True
        except Exception as e:
            print(f"✗ Error reading log: {e}")
            return False
    
    def show_connection_logs(self, lines: int = 50):
        """Show connection-related logs."""
        print(f"\n{'=' * 80}")
        print("CONNECTION LOGS".center(80))
        print(f"{'=' * 80}\n")
        
        cmd = [
            'journalctl', '-u', 'tailscaled', '-n', str(lines), '--no-pager'
        ]
        
        result = subprocess.run(cmd, capture_output=True, text=True)
        
        keywords = ['connect', 'disconnect', 'peer', 'established', 'lost']
        
        for line in result.stdout.split('\n'):
            if any(keyword in line.lower() for keyword in keywords):
                print(line)
    
    def show_error_logs(self, lines: int = 50):
        """Show error and warning logs."""
        print(f"\n{'=' * 80}")
        print("ERRORS AND WARNINGS".center(80))
        print(f"{'=' * 80}\n")
        
        cmd = [
            'journalctl', '-u', 'tailscaled', '-n', str(lines), '--no-pager'
        ]
        
        result = subprocess.run(cmd, capture_output=True, text=True)
        
        keywords = ['error', 'fail', 'warning', 'critical']
        
        for line in result.stdout.split('\n'):
            if any(keyword in line.lower() for keyword in keywords):
                print(line)
    
    def show_auth_logs(self, lines: int = 30):
        """Show authentication-related logs."""
        print(f"\n{'=' * 80}")
        print("AUTHENTICATION LOGS".center(80))
        print(f"{'=' * 80}\n")
        
        cmd = [
            'journalctl', '-u', 'tailscaled', '-n', str(lines), '--no-pager'
        ]
        
        result = subprocess.run(cmd, capture_output=True, text=True)
        
        keywords = ['auth', 'login', 'logout', 'key', 'token']
        
        for line in result.stdout.split('\n'):
            if any(keyword in line.lower() for keyword in keywords):
                print(line)
    
    def show_menu(self):
        """Display interactive menu."""
        while True:
            print("\n" + "=" * 80)
            print("TAILSCALE LOG VIEWER".center(80))
            print("=" * 80)
            print("\n📋 Log Sources:")
            print("  1. Tailscaled service logs (journalctl)")
            print("  2. System log (Tailscale entries)")
            print("  3. Tailscale log directory")
            
            print("\n🔍 Quick Views:")
            print("  4. Connection logs")
            print("  5. Error and warning logs")
            print("  6. Authentication logs")
            print("  7. Live tail")
            print("  0. Exit")
            
            choice = input("\nSelect option: ").strip()
            
            if choice == '0':
                print("\nGoodbye!")
                break
            
            elif choice == '1':
                filter_term = input("Filter term (Enter for none): ").strip()
                lines = input("Number of lines (default 50): ").strip()
                lines = int(lines) if lines.isdigit() else 50
                
                self.view_journal_logs(
                    filter_term if filter_term else None,
                    lines
                )
                
                input("\nPress Enter to continue...")
            
            elif choice == '2':
                log_file = '/var/log/syslog'
                filter_term = 'tailscale'
                lines = input("Number of lines (default 50): ").strip()
                lines = int(lines) if lines.isdigit() else 50
                
                self.view_file_logs(log_file, filter_term, lines)
                
                input("\nPress Enter to continue...")
            
            elif choice == '3':
                log_dir = Path('/var/log/tailscale')
                
                if not log_dir.exists():
                    print(f"\n✗ Log directory not found: {log_dir}")
                    input("\nPress Enter to continue...")
                    continue
                
                log_files = list(log_dir.glob('*.log'))
                
                if not log_files:
                    print(f"\n⚠ No log files found in {log_dir}")
                    input("\nPress Enter to continue...")
                    continue
                
                print(f"\nLog files in {log_dir}:")
                for i, log_file in enumerate(log_files, 1):
                    print(f"  {i}. {log_file.name}")
                
                file_choice = input("\nSelect file (or Enter to cancel): ").strip()
                
                if file_choice.isdigit() and 1 <= int(file_choice) <= len(log_files):
                    selected_file = log_files[int(file_choice) - 1]
                    
                    filter_term = input("Filter term (Enter for none): ").strip()
                    lines = input("Number of lines (default 50): ").strip()
                    lines = int(lines) if lines.isdigit() else 50
                    
                    self.view_file_logs(
                        str(selected_file),
                        filter_term if filter_term else None,
                        lines
                    )
                
                input("\nPress Enter to continue...")
            
            elif choice == '4':
                self.show_connection_logs()
                input("\nPress Enter to continue...")
            
            elif choice == '5':
                self.show_error_logs()
                input("\nPress Enter to continue...")
            
            elif choice == '6':
                self.show_auth_logs()
                input("\nPress Enter to continue...")
            
            elif choice == '7':
                filter_term = input("Filter term (Enter for none): ").strip()
                print("\nPress Ctrl+C to stop...\n")
                self.view_journal_logs(
                    filter_term if filter_term else None,
                    follow=True
                )
            
            else:
                print("Invalid option")


def main():
    """Main execution function."""
    viewer = TailscaleLogViewer()
    viewer.check_root()
    
    if len(sys.argv) > 1:
        if sys.argv[1] in ['-h', '--help']:
            print("Tailscale Log Viewer")
            print("\nUsage:")
            print("  Interactive mode: sudo ./tailscale_logs.py")
            print("  Direct view:      sudo ./tailscale_logs.py [filter] [lines]")
            print("\nExamples:")
            print("  sudo ./tailscale_logs.py")
            print("  sudo ./tailscale_logs.py error 100")
            sys.exit(0)
        
        filter_term = sys.argv[1] if len(sys.argv) > 1 else None
        lines = int(sys.argv[2]) if len(sys.argv) > 2 and sys.argv[2].isdigit() else 50
        
        viewer.view_journal_logs(filter_term, lines)
    else:
        viewer.show_menu()


if __name__ == '__main__':
    main()
