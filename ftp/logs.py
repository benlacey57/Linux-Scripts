#!/usr/bin/env python3
"""
FTP Log Viewer
Interactive viewer for FTP server logs
"""

import os
import sys
import subprocess
from pathlib import Path
from datetime import datetime, timedelta
from typing import List, Optional


class FTPLogViewer:
    """Interactive FTP log viewer."""
    
    def __init__(self):
        self.log_files = {
            '1': ('/var/log/vsftpd.log', 'vsftpd main log'),
            '2': ('/var/log/syslog', 'System log (vsftpd entries)'),
            '3': ('/var/log/auth.log', 'Authentication log'),
            '4': ('/var/log/fail2ban.log', 'fail2ban log'),
        }
    
    def check_root(self) -> bool:
        """Check if running as root."""
        if os.geteuid() != 0:
            print("⚠ Some log files may require root access")
            print("  Run with: sudo ./ftp_log_viewer.py")
            return False
        return True
    
    def filter_logs(self, log_file: str, filter_term: Optional[str] = None, 
                   lines: int = 50, follow: bool = False) -> bool:
        """Display filtered log content."""
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
                # Live tail
                cmd = ['tail', '-f', log_file]
                if filter_term:
                    grep_cmd = ['grep', '--line-buffered', '-i', filter_term]
                    tail_proc = subprocess.Popen(cmd, stdout=subprocess.PIPE)
                    grep_proc = subprocess.Popen(grep_cmd, stdin=tail_proc.stdout, stdout=sys.stdout)
                    grep_proc.communicate()
                else:
                    subprocess.run(cmd)
            else:
                # Show last N lines
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
    
    def show_errors_only(self, log_file: str, lines: int = 50):
        """Show only error entries."""
        print(f"\n{'=' * 80}")
        print(f"ERRORS FROM: {log_file}".center(80))
        print(f"{'=' * 80}\n")
        
        error_terms = ['error', 'fail', 'denied', 'refused', 'warning', 'critical']
        pattern = '|'.join(error_terms)
        
        cmd = f"tail -{lines} {log_file} | grep -iE '{pattern}'"
        subprocess.run(cmd, shell=True)
    
    def show_user_activity(self, username: str, lines: int = 50):
        """Show activity for specific user."""
        print(f"\n{'=' * 80}")
        print(f"ACTIVITY FOR USER: {username}".center(80))
        print(f"{'=' * 80}\n")
        
        log_file = '/var/log/vsftpd.log'
        
        if not Path(log_file).exists():
            log_file = '/var/log/syslog'
        
        cmd = f"tail -{lines} {log_file} | grep -i '{username}'"
        subprocess.run(cmd, shell=True)
    
    def show_recent_logins(self, lines: int = 20):
        """Show recent successful logins."""
        print(f"\n{'=' * 80}")
        print("RECENT SUCCESSFUL LOGINS".center(80))
        print(f"{'=' * 80}\n")
        
        cmd = "tail -100 /var/log/vsftpd.log | grep -i 'OK LOGIN' | tail -" + str(lines)
        subprocess.run(cmd, shell=True)
    
    def show_failed_logins(self, lines: int = 20):
        """Show recent failed logins."""
        print(f"\n{'=' * 80}")
        print("RECENT FAILED LOGINS".center(80))
        print(f"{'=' * 80}\n")
        
        cmd = "tail -100 /var/log/vsftpd.log | grep -iE 'FAIL|denied' | tail -" + str(lines)
        subprocess.run(cmd, shell=True)
    
    def show_menu(self):
        """Display interactive menu."""
        while True:
            print("\n" + "=" * 80)
            print("FTP LOG VIEWER".center(80))
            print("=" * 80)
            print("\n📋 Available Logs:")
            
            for key, (path, description) in self.log_files.items():
                exists = "✓" if Path(path).exists() else "✗"
                print(f"  {key}. {exists} {description}")
            
            print("\n🔍 Quick Views:")
            print("  5. Show recent successful logins")
            print("  6. Show recent failed logins")
            print("  7. Show errors only")
            print("  8. Show user activity")
            print("  9. Live tail log")
            print("  0. Exit")
            
            choice = input("\nSelect option: ").strip()
            
            if choice == '0':
                print("\nGoodbye!")
                break
            
            elif choice in self.log_files:
                log_file, description = self.log_files[choice]
                
                filter_term = input("Filter term (Enter for none): ").strip()
                lines = input("Number of lines (default 50): ").strip()
                lines = int(lines) if lines.isdigit() else 50
                
                self.filter_logs(
                    log_file,
                    filter_term if filter_term else None,
                    lines
                )
                
                input("\nPress Enter to continue...")
            
            elif choice == '5':
                self.show_recent_logins()
                input("\nPress Enter to continue...")
            
            elif choice == '6':
                self.show_failed_logins()
                input("\nPress Enter to continue...")
            
            elif choice == '7':
                log_choice = input("Which log? (1-4): ").strip()
                if log_choice in self.log_files:
                    log_file, _ = self.log_files[log_choice]
                    self.show_errors_only(log_file)
                input("\nPress Enter to continue...")
            
            elif choice == '8':
                username = input("Username: ").strip()
                if username:
                    self.show_user_activity(username)
                input("\nPress Enter to continue...")
            
            elif choice == '9':
                log_choice = input("Which log to tail? (1-4): ").strip()
                if log_choice in self.log_files:
                    log_file, _ = self.log_files[log_choice]
                    filter_term = input("Filter term (Enter for none): ").strip()
                    print("\nPress Ctrl+C to stop...\n")
                    self.filter_logs(
                        log_file,
                        filter_term if filter_term else None,
                        follow=True
                    )
            
            else:
                print("Invalid option")


def main():
    """Main execution function."""
    viewer = FTPLogViewer()
    viewer.check_root()
    
    if len(sys.argv) > 1:
        # Command-line mode
        if sys.argv[1] in ['-h', '--help']:
            print("FTP Log Viewer")
            print("\nUsage:")
            print("  Interactive mode: ./ftp_log_viewer.py")
            print("  Direct view:      ./ftp_log_viewer.py <log_file> [filter] [lines]")
            print("\nExamples:")
            print("  ./ftp_log_viewer.py")
            print("  ./ftp_log_viewer.py /var/log/vsftpd.log")
            print("  ./ftp_log_viewer.py /var/log/vsftpd.log error 100")
            sys.exit(0)
        
        log_file = sys.argv[1]
        filter_term = sys.argv[2] if len(sys.argv) > 2 else None
        lines = int(sys.argv[3]) if len(sys.argv) > 3 and sys.argv[3].isdigit() else 50
        
        viewer.filter_logs(log_file, filter_term, lines)
    else:
        # Interactive mode
        viewer.show_menu()


if __name__ == '__main__':
    main()
