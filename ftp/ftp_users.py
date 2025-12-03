#!/usr/bin/env python3
"""
FTP User Management Script
Creates and manages FTP users with secure password generation
"""

import os
import sys
import json
import subprocess
import secrets
import string
import csv
from pathlib import Path
from typing import Dict, Any, Optional, Tuple
from datetime import datetime


class PasswordGenerator:
    """Generates secure passwords based on policy."""
    
    def __init__(self, policy: Dict[str, Any]):
        self.policy = policy
        self.length = policy.get('length', 16)
        self.include_uppercase = policy.get('include_uppercase', True)
        self.include_lowercase = policy.get('include_lowercase', True)
        self.include_digits = policy.get('include_digits', True)
        self.include_special = policy.get('include_special', True)
        self.special_chars = policy.get('special_chars', '!@#$%^&*-_=+')
        self.exclude_ambiguous = policy.get('exclude_ambiguous', True)
    
    def generate(self) -> str:
        """Generate a secure password."""
        charset = ''
        password_chars = []
        
        # Build character set
        if self.include_lowercase:
            lowercase = string.ascii_lowercase
            if self.exclude_ambiguous:
                lowercase = lowercase.replace('l', '').replace('o', '')
            charset += lowercase
            # Ensure minimum lowercase
            for _ in range(self.policy.get('min_lowercase', 2)):
                password_chars.append(secrets.choice(lowercase))
        
        if self.include_uppercase:
            uppercase = string.ascii_uppercase
            if self.exclude_ambiguous:
                uppercase = uppercase.replace('I', '').replace('O', '')
            charset += uppercase
            # Ensure minimum uppercase
            for _ in range(self.policy.get('min_uppercase', 2)):
                password_chars.append(secrets.choice(uppercase))
        
        if self.include_digits:
            digits = string.digits
            if self.exclude_ambiguous:
                digits = digits.replace('0', '').replace('1', '')
            charset += digits
            # Ensure minimum digits
            for _ in range(self.policy.get('min_digits', 2)):
                password_chars.append(secrets.choice(digits))
        
        if self.include_special:
            charset += self.special_chars
            # Ensure minimum special
            for _ in range(self.policy.get('min_special', 2)):
                password_chars.append(secrets.choice(self.special_chars))
        
        # Fill remaining length with random characters from full charset
        remaining_length = self.length - len(password_chars)
        for _ in range(remaining_length):
            password_chars.append(secrets.choice(charset))
        
        # Shuffle to avoid predictable patterns
        secrets.SystemRandom().shuffle(password_chars)
        
        return ''.join(password_chars)


class FTPUserManager:
    """Manages FTP user accounts."""
    
    def __init__(self, config_file: str = "settings.json"):
        self.config = self._load_config(config_file)
        self.ftp_config = self.config.get('ftp_config', {})
        self.password_policy = self.config.get('password_policy', {})
        self.user_defaults = self.config.get('user_defaults', {})
        self.logging_config = self.config.get('logging', {})
        self.password_generator = PasswordGenerator(self.password_policy)
    
    def _load_config(self, config_file: str) -> Dict[str, Any]:
        """Load configuration from JSON file."""
        config_path = Path(config_file)
        
        if not config_path.exists():
            print(f"✗ Configuration file not found: {config_file}")
            sys.exit(1)
        
        try:
            with open(config_path, 'r') as f:
                return json.load(f)
        except json.JSONDecodeError as e:
            print(f"✗ Invalid JSON in configuration file: {e}")
            sys.exit(1)
    
    def check_root(self) -> bool:
        """Check if script is run as root."""
        if os.geteuid() != 0:
            print("✗ This script must be run as root")
            return False
        return True
    
    def user_exists(self, username: str) -> bool:
        """Check if user already exists."""
        try:
            subprocess.run(
                ['id', username],
                capture_output=True,
                check=True
            )
            return True
        except subprocess.CalledProcessError:
            return False
    
    def validate_username(self, username: str) -> Tuple[bool, str]:
        """Validate username meets requirements."""
        if not username:
            return False, "Username cannot be empty"
        
        if len(username) < 3:
            return False, "Username must be at least 3 characters"
        
        if len(username) > 32:
            return False, "Username must be 32 characters or less"
        
        if not username[0].isalpha():
            return False, "Username must start with a letter"
        
        if not all(c.isalnum() or c in '-_' for c in username):
            return False, "Username can only contain letters, numbers, hyphens, and underscores"
        
        if username in ['root', 'admin', 'administrator', 'ftp', 'test']:
            return False, "Username is reserved"
        
        return True, ""
    
    def create_user(self, username: str, password: Optional[str] = None) -> Tuple[bool, str, str]:
        """
        Create FTP user account.
        
        Returns:
            Tuple of (success, username, password)
        """
        # Validate username
        valid, message = self.validate_username(username)
        if not valid:
            print(f"✗ Invalid username: {message}")
            return False, username, ""
        
        # Check if user exists
        if self.user_exists(username):
            print(f"⚠ User '{username}' already exists")
            return False, username, ""
        
        # Generate password if not provided
        if password is None:
            password = self.password_generator.generate()
        
        ftp_root = Path(self.ftp_config.get('ftp_root', '/srv/ftp'))
        user_home = ftp_root / username
        user_files = user_home / 'files'
        
        try:
            # Create user
            print(f"\n👤 Creating user: {username}")
            
            shell = self.ftp_config.get('default_shell', '/bin/bash')
            group = self.ftp_config.get('ftp_group', 'ftpusers')
            
            subprocess.run(
                ['useradd', '-m', '-d', str(user_home), '-s', shell, '-G', group, username],
                check=True,
                capture_output=True
            )
            
            # Set password
            process = subprocess.Popen(
                ['chpasswd'],
                stdin=subprocess.PIPE,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE
            )
            process.communicate(input=f"{username}:{password}".encode())
            
            if process.returncode != 0:
                raise subprocess.CalledProcessError(process.returncode, 'chpasswd')
            
            print(f"✓ User account created")
            
            # Create directory structure
            print(f"📁 Setting up directories...")
            
            # Create FTP directory (owned by root for chroot)
            user_home.mkdir(parents=True, exist_ok=True)
            os.chown(user_home, 0, 0)  # root:root
            os.chmod(user_home, 0o755)
            
            # Create writable files directory
            user_files.mkdir(exist_ok=True)
            
            # Get user UID/GID
            import pwd
            user_info = pwd.getpwnam(username)
            os.chown(user_files, user_info.pw_uid, user_info.pw_gid)
            os.chmod(user_files, 0o755)
            
            print(f"✓ Directory structure created")
            print(f"   Home: {user_home}")
            print(f"   Files: {user_files}")
            
            # Add to allowed users list
            userlist_file = Path(self.ftp_config.get('allowed_users_file', '/etc/vsftpd.userlist'))
            
            # Create userlist file if it doesn't exist
            if not userlist_file.exists():
                userlist_file.touch()
                os.chmod(userlist_file, 0o644)
            
            # Check if user already in list
            with open(userlist_file, 'r') as f:
                existing_users = [line.strip() for line in f]
            
            if username not in existing_users:
                with open(userlist_file, 'a') as f:
                    f.write(f"{username}\n")
                print(f"✓ Added to allowed users list")
            else:
                print(f"✓ Already in allowed users list")
            
            # Log credentials
            self._log_credentials(username, password)
            
            print(f"\n✓ User '{username}' created successfully")
            
            return True, username, password
            
        except subprocess.CalledProcessError as e:
            print(f"✗ Failed to create user: {e}")
            print(f"   Error output: {e.stderr.decode() if e.stderr else 'None'}")
            
            # Cleanup on failure
            try:
                if self.user_exists(username):
                    subprocess.run(['userdel', '-r', username], capture_output=True)
            except:
                pass
            
            return False, username, ""
        except Exception as e:
            print(f"✗ Unexpected error: {e}")
            return False, username, ""
    
    def _log_credentials(self, username: str, password: str):
        """Log credentials to CSV file."""
        if not self.logging_config.get('enabled', True):
            return
        
        credentials_file = Path(self.logging_config.get('credentials_file', '/root/.ftp_credentials.csv'))
        
        # Create parent directory if needed
        credentials_file.parent.mkdir(parents=True, exist_ok=True)
        
        # Check if file exists to determine if we need headers
        file_exists = credentials_file.exists()
        
        try:
            with open(credentials_file, 'a', newline='') as f:
                writer = csv.writer(f)
                
                if not file_exists:
                    writer.writerow(['Timestamp', 'Username', 'Password', 'Home Directory', 'Files Directory'])
                
                timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
                ftp_root = self.ftp_config.get('ftp_root', '/srv/ftp')
                home_dir = f"{ftp_root}/{username}"
                files_dir = f"{ftp_root}/{username}/files"
                
                writer.writerow([timestamp, username, password, home_dir, files_dir])
            
            # Secure the credentials file
            os.chmod(credentials_file, 0o600)  # Only root can read/write
            
            print(f"✓ Credentials saved to {credentials_file}")
            
        except IOError as e:
            print(f"⚠ Failed to log credentials: {e}")
    
    def delete_user(self, username: str, remove_home: bool = True) -> bool:
        """Delete FTP user account."""
        if not self.user_exists(username):
            print(f"✗ User '{username}' does not exist")
            return False
        
        print(f"\n🗑️  Deleting user: {username}")
        
        try:
            # Remove user
            cmd = ['userdel']
            if remove_home:
                cmd.append('-r')
            cmd.append(username)
            
            subprocess.run(cmd, check=True, capture_output=True)
            print(f"✓ User account deleted")
            
            # Remove from userlist
            userlist_file = Path(self.ftp_config.get('allowed_users_file', '/etc/vsftpd.userlist'))
            
            if userlist_file.exists():
                with open(userlist_file, 'r') as f:
                    lines = f.readlines()
                
                with open(userlist_file, 'w') as f:
                    for line in lines:
                        if line.strip() != username:
                            f.write(line)
                
                print(f"✓ Removed from allowed users list")
            
            print(f"\n✓ User '{username}' deleted successfully")
            return True
            
        except subprocess.CalledProcessError as e:
            print(f"✗ Failed to delete user: {e}")
            return False
    
    def change_password(self, username: str, new_password: Optional[str] = None) -> Tuple[bool, str]:
        """Change user password."""
        if not self.user_exists(username):
            print(f"✗ User '{username}' does not exist")
            return False, ""
        
        # Generate password if not provided
        if new_password is None:
            new_password = self.password_generator.generate()
        
        print(f"\n🔑 Changing password for: {username}")
        
        try:
            # Set password
            process = subprocess.Popen(
                ['chpasswd'],
                stdin=subprocess.PIPE,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE
            )
            process.communicate(input=f"{username}:{new_password}".encode())
            
            if process.returncode != 0:
                raise subprocess.CalledProcessError(process.returncode, 'chpasswd')
            
            print(f"✓ Password changed successfully")
            
            # Log new credentials
            self._log_credentials(username, new_password)
            
            return True, new_password
            
        except subprocess.CalledProcessError as e:
            print(f"✗ Failed to change password: {e}")
            return False, ""
    
    def list_users(self):
        """List all FTP users."""
        print("\n" + "=" * 80)
        print("FTP USERS".center(80))
        print("=" * 80 + "\n")
        
        userlist_file = Path(self.ftp_config.get('allowed_users_file', '/etc/vsftpd.userlist'))
        
        if not userlist_file.exists():
            print("⚠ No user list file found")
            print(f"   Expected at: {userlist_file}")
            return
        
        with open(userlist_file, 'r') as f:
            users = [line.strip() for line in f if line.strip() and not line.startswith('#')]
        
        if not users:
            print("No users found")
            return
        
        print(f"{'Username':<20} {'Home Directory':<40} {'Status'}")
        print("-" * 80)
        
        for username in users:
            if self.user_exists(username):
                ftp_root = self.ftp_config.get('ftp_root', '/srv/ftp')
                home_dir = f"{ftp_root}/{username}"
                
                # Check if directories exist
                if Path(home_dir).exists():
                    status = "✓ Active"
                else:
                    status = "⚠ Missing directories"
            else:
                home_dir = "N/A"
                status = "✗ User missing"
            
            print(f"{username:<20} {home_dir:<40} {status}")
        
        print("\n" + "=" * 80 + "\n")

      def show_user_info(self, username: str):
        """Show detailed information about a user."""
        print("\n" + "=" * 80)
        print(f"USER INFORMATION: {username}".center(80))
        print("=" * 80 + "\n")
        
        if not self.user_exists(username):
            print(f"✗ User '{username}' does not exist")
            return
        
        # Get user info
        import pwd
        try:
            user_info = pwd.getpwnam(username)
            
            print(f"Username: {username}")
            print(f"UID: {user_info.pw_uid}")
            print(f"GID: {user_info.pw_gid}")
            print(f"Home Directory: {user_info.pw_dir}")
            print(f"Shell: {user_info.pw_shell}")
            
            # Get groups
            code, stdout, stderr = subprocess.run(
                ['groups', username],
                capture_output=True,
                text=True
            ).returncode, subprocess.run(['groups', username], capture_output=True, text=True).stdout, ""
            
            groups = stdout.strip().split(':')[-1].strip() if stdout else "N/A"
            print(f"Groups: {groups}")
            
            # Check directories
            print(f"\nDirectory Status:")
            home_path = Path(user_info.pw_dir)
            files_path = home_path / 'files'
            
            if home_path.exists():
                stat = home_path.stat()
                print(f"  Home: ✓ {home_path}")
                print(f"    Owner: UID {stat.st_uid} (should be 0 for chroot)")
                print(f"    Permissions: {oct(stat.st_mode)[-3:]}")
            else:
                print(f"  Home: ✗ Missing - {home_path}")
            
            if files_path.exists():
                stat = files_path.stat()
                print(f"  Files: ✓ {files_path}")
                print(f"    Owner: UID {stat.st_uid}")
                print(f"    Permissions: {oct(stat.st_mode)[-3:]}")
            else:
                print(f"  Files: ✗ Missing - {files_path}")
            
            # Check if in allowed list
            userlist_file = Path(self.ftp_config.get('allowed_users_file', '/etc/vsftpd.userlist'))
            if userlist_file.exists():
                with open(userlist_file, 'r') as f:
                    allowed_users = [line.strip() for line in f]
                
                if username in allowed_users:
                    print(f"\nAllowed List: ✓ Present in {userlist_file}")
                else:
                    print(f"\nAllowed List: ✗ Not in {userlist_file}")
            
        except KeyError:
            print(f"✗ Could not retrieve user information")
        
        print("\n" + "=" * 80 + "\n")
    
    def interactive_create(self):
        """Interactive user creation."""
        print("\n" + "=" * 80)
        print("CREATE NEW FTP USER".center(80))
        print("=" * 80)
        
        while True:
            username = input("\nEnter username (or 'quit' to exit): ").strip()
            
            if username.lower() in ['quit', 'q', 'exit']:
                break
            
            valid, message = self.validate_username(username)
            if not valid:
                print(f"✗ {message}")
                continue
            
            if self.user_exists(username):
                print(f"⚠ User '{username}' already exists")
                continue
            
            # Ask if custom password is needed
            use_custom = input("Use custom password? (y/N): ").strip().lower()
            
            if use_custom == 'y':
                import getpass
                password = getpass.getpass("Enter password: ")
                password_confirm = getpass.getpass("Confirm password: ")
                
                if password != password_confirm:
                    print("✗ Passwords do not match")
                    continue
            else:
                password = None
                print("✓ Password will be auto-generated")
            
            # Create user
            success, username, generated_password = self.create_user(username, password)
            
            if success:
                print("\n" + "=" * 80)
                print("USER CREATED SUCCESSFULLY".center(80))
                print("=" * 80)
                print(f"\n📝 Credentials:")
                print(f"   Username: {username}")
                print(f"   Password: {generated_password}")
                print(f"\n📁 Directories:")
                print(f"   FTP Root: {self.ftp_config.get('ftp_root', '/srv/ftp')}/{username}")
                print(f"   Writable: {self.ftp_config.get('ftp_root', '/srv/ftp')}/{username}/files")
                print(f"\n🔒 Credentials saved to: {self.logging_config.get('credentials_file', '/root/.ftp_credentials.csv')}")
                print("\n" + "=" * 80)
                
                another = input("\nCreate another user? (y/N): ").strip().lower()
                if another != 'y':
                    break
    
    def show_menu(self):
        """Display main menu."""
        while True:
            print("\n" + "=" * 80)
            print("FTP USER MANAGER".center(80))
            print("=" * 80)
            print("\n1. Create new user")
            print("2. Delete user")
            print("3. Change user password")
            print("4. List all users")
            print("5. Show user information")
            print("6. View credentials file")
            print("7. Exit")
            
            choice = input("\nSelect option: ").strip()
            
            if choice == '1':
                self.interactive_create()
            
            elif choice == '2':
                username = input("\nEnter username to delete: ").strip()
                if not username:
                    continue
                
                # Show user info first
                if self.user_exists(username):
                    self.show_user_info(username)
                
                confirm = input(f"\nDelete user '{username}' and their files? (yes/no): ").strip().lower()
                if confirm == 'yes':
                    self.delete_user(username, remove_home=True)
                else:
                    print("Cancelled")
            
            elif choice == '3':
                username = input("\nEnter username: ").strip()
                if not username:
                    continue
                
                if not self.user_exists(username):
                    print(f"✗ User '{username}' does not exist")
                    continue
                
                use_custom = input("Use custom password? (y/N): ").strip().lower()
                
                if use_custom == 'y':
                    import getpass
                    password = getpass.getpass("Enter new password: ")
                    password_confirm = getpass.getpass("Confirm password: ")
                    
                    if password != password_confirm:
                        print("✗ Passwords do not match")
                        continue
                else:
                    password = None
                
                success, new_password = self.change_password(username, password)
                
                if success:
                    print(f"\n✓ Password changed successfully")
                    print(f"   New password: {new_password}")
            
            elif choice == '4':
                self.list_users()
            
            elif choice == '5':
                username = input("\nEnter username: ").strip()
                if username:
                    self.show_user_info(username)
            
            elif choice == '6':
                credentials_file = Path(self.logging_config.get('credentials_file', '/root/.ftp_credentials.csv'))
                
                if not credentials_file.exists():
                    print(f"\n✗ Credentials file not found: {credentials_file}")
                else:
                    print(f"\n📄 Credentials File: {credentials_file}\n")
                    with open(credentials_file, 'r') as f:
                        content = f.read()
                        print(content)
                
                input("\nPress Enter to continue...")
            
            elif choice == '7' or choice.lower() in ['quit', 'q', 'exit']:
                print("\nGoodbye!")
                break
            
            else:
                print("✗ Invalid option")


def main():
    """Main execution function."""
    config_file = "settings.json"
    
    if len(sys.argv) > 1:
        if sys.argv[1] in ['-h', '--help']:
            print("FTP User Management Script")
            print("\nUsage:")
            print("  Interactive mode: sudo ./ftp_users.py")
            print("  With config file:  sudo ./ftp_users.py <config_file>")
            print("\nExamples:")
            print("  sudo ./ftp_users.py")
            print("  sudo ./ftp_users.py /path/to/settings.json")
            sys.exit(0)
        
        config_file = sys.argv[1]
    
    manager = FTPUserManager(config_file)
    
    if not manager.check_root():
        sys.exit(1)
    
    manager.show_menu()


if __name__ == '__main__':
    main()
