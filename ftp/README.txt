FTP Scripts
Version: 1.0

TABLE OF CONTENTS
-----------------
1. Overview
2. Prerequisites
3. Installation
4. Configuration
5. Server Setup
6. User Management
7. Debugging
8. Log Viewing
9. Common Issues
10. Security Best Practices
11. File Locations

================================================================================
1. OVERVIEW
================================================================================

This suite provides comprehensive tools for setting up and managing an FTP/SFTP
server with secure user management, automated password generation, debugging
tools, and log viewing capabilities.

Components:
  - ftp_setup.py     : Server installation and configuration
  - ftp_users.py     : User creation and management
  - ftp_debug.py     : Diagnostic and troubleshooting tool
  - ftp_logs.py      : Interactive log viewer
  - settings.json    : Configuration file

================================================================================
2. PREREQUISITES
================================================================================

System Requirements:
  - Ubuntu/Debian Linux (tested on Ubuntu 20.04+)
  - Python 3.6 or higher
  - Root/sudo access
  - Internet connection for package installation

Python Packages:
  - No external packages required (uses standard library only)

================================================================================
3. INSTALLATION
================================================================================

Step 1: Download/Clone Files
-----------------------------
Ensure all files are in the same directory:
  - ftp_setup.py
  - ftp_users py
  - ftp_debug.py
  - ftp_logs.py
  - settings.json

Step 2: Make Scripts Executable
--------------------------------
chmod +x ftp_setup.py
chmod +x ftp_users.py
chmod +x ftp_debug.py
chmod +x ftp_logs.py

Step 3: Review Configuration
-----------------------------
Edit settings.json to match your requirements (see section 4)

================================================================================
4. CONFIGURATION (settings.json)
================================================================================

FTP Configuration Section:
--------------------------
ftp_root              : Base directory for FTP users (default: /srv/ftp)
default_shell         : User shell (default: /bin/bash)
ftp_group             : Group name for FTP users (default: ftpusers)
allowed_users_file    : Path to vsftpd userlist (default: /etc/vsftpd.userlist)
passive_port_min/max  : Port range for passive mode (default: 40000-40100)
max_clients           : Maximum simultaneous clients (default: 50)
max_per_ip            : Maximum connections per IP (default: 5)

Password Policy:
----------------
length                : Password length (default: 16)
include_uppercase     : Include uppercase letters (default: true)
include_lowercase     : Include lowercase letters (default: true)
include_digits        : Include numbers (default: true)
include_special       : Include special characters (default: true)
special_chars         : Allowed special characters (default: !@#$%^&*-_=+)
exclude_ambiguous     : Exclude ambiguous characters like 0/O, 1/l (default: true)
min_uppercase         : Minimum uppercase letters (default: 2)
min_lowercase         : Minimum lowercase letters (default: 2)
min_digits            : Minimum digits (default: 2)
min_special           : Minimum special characters (default: 2)

Security Settings:
------------------
fail2ban_enabled      : Enable fail2ban protection (default: true)
max_login_fails       : Failed attempts before ban (default: 3)
ban_time_minutes      : Ban duration in minutes (default: 60)

Logging Settings:
-----------------
enabled               : Enable credential logging (default: true)
log_file              : Path to management log file
credentials_file      : Path to credentials CSV (default: /root/.ftp_credentials.csv)

================================================================================
5. SERVER SETUP
================================================================================

Initial Setup:
--------------
1. Review and edit settings.json
2. Run the setup script:
   
   sudo ./ftp_setup.py

3. The script will:
   - Install required packages (vsftpd, openssh-server, fail2ban)
   - Create FTP group
   - Configure vsftpd
   - Configure SSH/SFTP
   - Set up firewall rules
   - Configure fail2ban
   - Start services

4. Verify setup completed successfully

Server will be available on:
  - FTP:  Port 21
  - SFTP: Port 22
  - Passive ports: 40000-40100 (configurable)

Firewall Ports:
---------------
The following ports are opened:
  - 20/tcp  : FTP data
  - 21/tcp  : FTP control
  - 22/tcp  : SSH/SFTP
  - 40000-40100/tcp : FTP passive mode

================================================================================
6. USER MANAGEMENT
================================================================================

Creating Users:
---------------
Interactive Mode:
  sudo ./ftp_users.py

The script will:
  1. Prompt for username
  2. Validate username
  3. Option for custom or auto-generated password
  4. Create user account
  5. Set up directory structure
  6. Add user to allowed list
  7. Log credentials

User Directory Structure:
-------------------------
/srv/ftp/          (owned by root, for chroot security)
├── username/        (owned by user, writable directory)

Credentials Storage:
--------------------
All credentials are saved to /root/.ftp_credentials.csv with permissions 600
Format: Timestamp, Username, Password, Home Directory

Deleting Users:
---------------
Option 2 in the user manager menu
Will remove:
  - User account
  - Home directory (optional)
  - Entry from allowed users list

Listing Users:
--------------
Option 3 in the user manager menu
Shows:
  - All FTP users
  - Home directories
  - Account status

================================================================================
7. DEBUGGING
================================================================================

Running Diagnostics:
--------------------
Basic diagnostics:
  sudo ./ftp_debug.py

With specific user test:
  sudo ./ftp_debug.py settings.json username

The debug tool checks:
  - Service status (vsftpd, SSH)
  - Port listening status
  - Firewall configuration
  - vsftpd configuration
  - User list and accounts
  - Directory permissions
  - Network connectivity
  - Recent log entries

Output Sections:
----------------
SERVICE STATUS          : Are services running?
PORT LISTENING STATUS   : Are ports open?
FIREWALL STATUS         : Are ports allowed?
CONFIGURATION CHECKS    : Is vsftpd configured correctly?
USER LIST CHECKS        : Do users exist with correct permissions?
PERMISSION CHECKS       : Are directory permissions correct?
NETWORK CHECKS          : Is server reachable?
LOG FILE ANALYSIS       : Any recent errors?
DIAGNOSTIC SUMMARY      : Overview of issues found
SUGGESTED FIXES         : Commands to fix issues

Interpreting Results:
---------------------
✓ : Check passed
⚠ : Warning (may be normal)
✗ : Issue found (needs attention)

================================================================================
8. LOG VIEWING
================================================================================

Interactive Mode:
-----------------
sudo ./ftp_logs.py

Available Options:
  1. vsftpd main log        : Primary FTP activity log
  2. System log             : System-wide log (includes FTP entries)
  3. Authentication log     : Login attempts and authentication
  4. fail2ban log           : Ban activity
  5. Recent successful logins
  6. Recent failed logins
  7. Show errors only
  8. Show user activity
  9. Live tail log
  0. Exit

Command-Line Mode:
------------------
View specific log:
  sudo ./ftp_logs.py /var/log/vsftpd.log

With filter:
  sudo ./ftp_logs.py /var/log/vsftpd.log error

With filter and line limit:
  sudo ./ftp_logs.py /var/log/vsftpd.log username 100

Live Monitoring:
----------------
Use option 9 in interactive mode to watch logs in real-time
Press Ctrl+C to stop

================================================================================
9. COMMON ISSUES
================================================================================

Issue: Cannot connect to FTP
-----------------------------
Fixes:
1. Check service is running:
   sudo systemctl status vsftpd
   
2. Check port is listening:
   sudo netstat -tuln | grep :21
   
3. Check firewall:
   sudo ufw status
   
4. Check logs:
   sudo tail -f /var/log/vsftpd.log

Issue: "500 OOPS: vsftpd: refusing to run with writable root inside chroot()"
------------------------------------------------------------------------------
Fix:
sudo chown root:root /srv/ftp/username
sudo chmod 755 /srv/ftp/username

Issue: User can login but cannot write files
---------------------------------------------
Fix:
sudo chown username:ftpusers /srv/ftp/username/
sudo chmod 755 /srv/ftp/username/

Issue: Cannot access files directory
-------------------------------------
Fix:
sudo mkdir -p /srv/ftp/username/
sudo chown username:ftpusers /srv/ftp/username/

Issue: Passive mode not working
--------------------------------
Fix:
1. Ensure passive ports are open in firewall
2. Check vsftpd.conf has:
   pasv_enable=YES
   pasv_min_port=40000
   pasv_max_port=40100

Issue: fail2ban blocking legitimate users
------------------------------------------
Fix:
1. Unban IP:
   sudo fail2ban-client set vsftpd unbanip <IP_ADDRESS>
   
2. Check banned IPs:
   sudo fail2ban-client status vsftpd

================================================================================
10. SECURITY BEST PRACTICES
================================================================================

1. Strong Passwords:
   - Use auto-generated passwords
   - Minimum 16 characters
   - Include mixed case, digits, and special characters

2. Regular Updates:
   sudo apt update && sudo apt upgrade

3. Monitor Logs:
   - Check failed login attempts regularly
   - Review /var/log/vsftpd.log daily
   - Monitor fail2ban activity

4. Limit User Access:
   - Only create necessary user accounts
   - Remove unused accounts promptly
   - Use chroot to restrict user access

5. Firewall:
   - Keep UFW enabled
   - Only open required ports
   - Consider IP whitelisting for known clients

6. fail2ban:
   - Keep enabled
   - Adjust max_login_fails if needed
   - Review banned IPs regularly

7. File Permissions:
   - FTP root owned by root (chroot security)
   - User files directory owned by user
   - Credentials file (600 permissions)

8. Backups:
   - Backup /etc/vsftpd.conf
   - Backup /etc/vsftpd.userlist
   - Backup /root/.ftp_credentials.csv
   - Backup user data regularly

9. SFTP vs FTP:
   - Prefer SFTP (port 22) over FTP when possible
   - SFTP is encrypted, FTP is not
   - Both are configured by this suite

10. Regular Audits:
    - Run debug script monthly
    - Review user list quarterly
    - Check for unused accounts

================================================================================
11. FILE LOCATIONS
================================================================================

Configuration Files:
--------------------
/etc/vsftpd.conf              : Main vsftpd configuration
/etc/vsftpd.userlist          : Allowed FTP users
/etc/ssh/sshd_config          : SSH/SFTP configuration
/etc/fail2ban/jail.local      : fail2ban configuration
settings.json                 : Suite configuration

Log Files:
----------
/var/log/vsftpd.log           : FTP activity log
/var/log/syslog               : System log
/var/log/auth.log             : Authentication log
/var/log/fail2ban.log         : fail2ban activity
/var/log/ftp_management.log   : Management script log

Data Directories:
-----------------
/srv/ftp/                     : FTP root (configurable)
/srv/ftp/username/            : User home directory
/srv/ftp/username/files/      : User writable directory

Credentials:
------------
/root/.ftp_credentials.csv    : Stored credentials (600 permissions)

================================================================================
QUICK REFERENCE COMMANDS
================================================================================

Service Management:
-------------------
sudo systemctl start vsftpd
sudo systemctl stop vsftpd
sudo systemctl restart vsftpd
sudo systemctl status vsftpd

User Management:
----------------
sudo ./ftp_users.py           # Interactive menu
sudo userdel -r username      # Delete user
sudo passwd username          # Change password

Debugging:
----------
sudo ./ftp_debug.py                  # Full diagnostics
sudo netstat -tuln | grep :21        # Check FTP port
sudo tail -f /var/log/vsftpd.log     # Watch logs
sudo ./ftp_logs.py                   # Interactive log viewer

Firewall:
---------
sudo ufw status                         # Check status
sudo ufw allow 21/tcp                   # Allow FTP
sudo ufw reload                         # Reload rules

fail2ban:
---------
sudo fail2ban-client status vsftpd             # Check status
sudo fail2ban-client set vsftpd unbanip <IP>   # Unban IP

Testing:
--------
ftp localhost                           # Test FTP locally
sftp username@localhost                 # Test SFTP locally

================================================================================
SUPPORT & TROUBLESHOOTING
================================================================================

For issues:
1. Run: sudo ./ftp_debug.py
2. Check logs: sudo ./ftp_logs.py
3. Review this README
4. Check vsftpd documentation: man vsftpd.conf

Common commands:
- Check if port is open: sudo netstat -tuln | grep :21
- Test FTP connection: ftp localhost
- View recent errors: sudo tail -100 /var/log/vsftpd.log | grep -i error
- Check user exists: id username
- Verify directory: ls -la /srv/ftp/username/
                             
