TailScale Scripts
Version: 1.0

TABLE OF CONTENTS
-----------------
1. Overview
2. Prerequisites
3. Installation
4. Configuration
5. Server Setup
6. Debugging
7. Log Viewing
8. Common Tasks
9. Troubleshooting
10. Security Considerations
11. File Locations

================================================================================
1. OVERVIEW
================================================================================

This suite provides comprehensive tools for setting up and managing Tailscale
VPN with automated installation, configuration, debugging, and log viewing
capabilities.

Components:
  - tailscale_setup.py   : Installation and configuration
  - tailscale_debug.py   : Diagnostic and troubleshooting tool
  - tailscale_logs.py    : Interactive log viewer
  - settings.json        : Configuration file

What is Tailscale?
  Tailscale is a zero-config VPN that creates a secure network between your
  devices using WireGuard. It provides:
  - Encrypted peer-to-peer connections
  - Simple setup with no port forwarding
  - MagicDNS for easy device naming
  - ACL-based access control
  - Exit nodes for routing traffic

================================================================================
2. PREREQUISITES
================================================================================

System Requirements:
  - Ubuntu/Debian Linux (tested on Ubuntu 20.04+)
  - Python 3.6 or higher
  - Root/sudo access
  - Internet connection
  - Active Tailscale account (free tier available)

Python Packages:
  - No external packages required (uses standard library only)

================================================================================
3. INSTALLATION
================================================================================

Step 1: Download/Clone Files
-----------------------------
Ensure all files are in the same directory:
  - tailscale_setup.py
  - tailscale_debug.py
  - tailscale_logs.py
  - settings.json

Step 2: Make Scripts Executable
--------------------------------
chmod +x tailscale_setup.py
chmod +x tailscale_debug.py
chmod +x tailscale_logs.py

Step 3: Review Configuration
-----------------------------
Edit settings.json to match your requirements (see section 4)

================================================================================
4. CONFIGURATION (settings.json)
================================================================================

Tailscale Configuration:
------------------------
hostname                  : Custom hostname for this machine (leave empty for default)
accept_routes             : Accept subnet routes from other nodes (default: true)
accept_dns                : Use Tailscale DNS/MagicDNS (default: true)
shields_up                : Block incoming connections (default: false)
advertise_exit_node       : Advertise as exit node (default: false)
advertise_routes          : Subnets to advertise (e.g., ["192.168.1.0/24"])
ssh_enabled               : Enable Tailscale SSH (default: true)
operator                  : Unix user who can operate tailscale (default: empty)

Network Configuration:
----------------------
ipv4_enabled              : Enable IPv4 (default: true)
ipv6_enabled              : Enable IPv6 (default: false)
exit_node                 : Use specific exit node (hostname or IP)
exit_node_allow_lan_access: Allow LAN access when using exit node (default: true)

Logging:
--------
enabled                   : Enable logging (default: true)
log_file                  : Path to management log
verbose_logging           : Enable verbose Tailscale logging (default: false)

================================================================================
5. SERVER SETUP
================================================================================

Initial Setup:
--------------
1. Review and edit settings.json
2. Run the setup script:
   
   sudo ./tailscale_setup.py

3. The script will:
   - Download and install Tailscale
   - Enable IP forwarding (if needed)
   - Start authentication process
   - Configure settings from JSON
   - Verify installation

4. Complete authentication in browser when prompted

Authentication:
---------------
When you run the setup, a browser window will open asking you to:
1. Sign in to your Tailscale account (or create one)
2. Authorize this machine
3. Choose which tailnet to join (if you have multiple)

The script will wait for you to complete this process.

Manual Authentication:
----------------------
If you need to authenticate later:
  sudo tailscale up

To logout:
  sudo tailscale logout

================================================================================
6. DEBUGGING
================================================================================

Running Diagnostics:
--------------------
Basic diagnostics:
  sudo ./tailscale_debug.py

With custom config:
  sudo ./tailscale_debug.py /path/to/settings.json

The debug tool checks:
  - Installation status
  - Service status
  - Authentication status
  - IP address assignment
  - Peer connectivity
  - Route configuration
  - Exit node status
  - DNS configuration
  - SSH configuration
  - Firewall status
  - Connectivity to Tailscale servers
  - Recent log entries

Output Sections:
----------------
INSTALLATION CHECK        : Is Tailscale installed?
SERVICE STATUS            : Is tailscaled running?
AUTHENTICATION STATUS     : Are you logged in?
IP ADDRESS CHECK          : Do you have Tailscale IPs?
CONNECTIVITY STATUS       : Connected to peers?
ROUTE CONFIGURATION       : Routes advertised/accepted?
EXIT NODE STATUS          : Exit node configured?
DNS CONFIGURATION         : MagicDNS working?
SSH CONFIGURATION         : Tailscale SSH enabled?
FIREWALL STATUS           : Firewall configuration
CONNECTIVITY TEST         : Can reach Tailscale servers?
LOG ANALYSIS              : Any recent errors?
DIAGNOSTIC SUMMARY        : Overview of issues

Interpreting Results:
---------------------
✓ : Check passed
⚠ : Warning (may be normal)
✗ : Issue found (needs attention)

================================================================================
7. LOG VIEWING
================================================================================

Interactive Mode:
-----------------
sudo ./tailscale_logs.py

Available Options:
  1. Tailscaled service logs    : Main Tailscale daemon logs
  2. System log                 : System log Tailscale entries
  3. Tailscale log directory    : Additional log files
  4. Connection logs            : Connection/disconnection events
  5. Error and warning logs     : Problems and warnings
  6. Authentication logs        : Login/logout events
  7. Live tail                  : Real-time log monitoring
  0. Exit

Command-Line Mode:
------------------
View logs with filter:
  sudo ./tailscale_logs.py error

View specific number of lines:
  sudo ./tailscale_logs.py connection 100

Direct journalctl access:
  sudo journalctl -u tailscaled -f

================================================================================
8. COMMON TASKS
================================================================================

Check Status:
-------------
tailscale status
tailscale status --peers      # Show all peers

Get Your IP:
------------
tailscale ip -4              # IPv4 address
tailscale ip -6              # IPv6 address

Connect to Peer:
----------------
ssh user@hostname            # Using Tailscale SSH
ssh user@100.x.x.x          # Using Tailscale IP

Enable Exit Node:
-----------------
# On the exit node machine:
1. Edit settings.json: "advertise_exit_node": true
2. Run: sudo ./tailscale_setup.py

# On client machines:
tailscale up --exit-node=hostname
# or
tailscale set --exit-node=hostname

Disable Exit Node:
------------------
tailscale set --exit-node=

Advertise Subnet Routes:
------------------------
# Edit settings.json:
"advertise_routes": ["192.168.1.0/24", "10.0.0.0/8"]

# Re-run setup:
sudo ./tailscale_setup.py

# Approve routes in admin console:
https://login.tailscale.com/admin/machines

Accept Routes from Others:
--------------------------
tailscale up --accept-routes

Enable MagicDNS:
----------------
# In Tailscale admin console:
https://login.tailscale.com/admin/dns
Enable MagicDNS

Share Files:
------------
# Send file to peer:
tailscale file cp myfile.txt hostname:

# Receive files:
tailscale file get ~/Downloads/

Update Hostname:
----------------
tailscale set --hostname=new-name

================================================================================
9. TROUBLESHOOTING
================================================================================

Issue: Cannot authenticate
---------------------------
Symptoms: Browser doesn't open, or authentication fails
Fixes:
1. Check internet connection:
   ping tailscale.com
   
2. Try manual authentication:
   sudo tailscale up
   
3. Check service is running:
   sudo systemctl status tailscaled
   
4. View logs:
   sudo journalctl -u tailscaled -f

Issue: No peers showing
-----------------------
Symptoms: tailscale status shows no peers
Fixes:
1. Verify authentication:
   tailscale status
   
2. Check other devices are online:
   https://login.tailscale.com/admin/machines
   
3. Restart Tailscale:
   sudo systemctl restart tailscaled
   
4. Check firewall isn't blocking:
   sudo ./tailscale_debug.py

Issue: Cannot connect to peer
------------------------------
Symptoms: Can see peer but cannot SSH/ping
Fixes:
1. Verify IP address:
   tailscale ip -4
   
2. Check peer's firewall:
   - Ensure peer accepts connections
   - Check "shields-up" mode: tailscale status
   
3. Try both hostname and IP:
   ssh user@hostname
   ssh user@100.x.x.x
   
4. Check ACLs in admin console

Issue: Exit node not working
-----------------------------
Symptoms: Traffic not routing through exit node
Fixes:
1. Verify exit node is online:
   tailscale status
   
2. Check IP forwarding on exit node:
   sysctl net.ipv4.ip_forward
   
3. Approve exit node in admin console:
   https://login.tailscale.com/admin/machines
   
4. Set exit node explicitly:
   tailscale set --exit-node=hostname

Issue: DNS not resolving
-------------------------
Symptoms: Cannot resolve machine names
Fixes:
1. Check MagicDNS is enabled:
   https://login.tailscale.com/admin/dns
   
2. Verify accepting DNS:
   tailscale status
   
3. Check /etc/resolv.conf:
   cat /etc/resolv.conf | grep 100.100.100.100
   
4. Restart with DNS:
   sudo tailscale down
   sudo tailscale up --accept-dns

Issue: High latency/poor performance
-------------------------------------
Fixes:
1. Check connection type:
   tailscale status
   Look for "relay" vs "direct" connections
   
2. Verify UDP not blocked:
   - Port 41641/udp should be allowed
   - Some networks block UDP
   
3. Try different network:
   - Some corporate networks block P2P
   
4. Check exit node performance:
   - Exit nodes can add latency

Issue: "Operation not permitted" errors
----------------------------------------
Fixes:
1. Ensure running as root:
   sudo tailscale up
   
2. Check service status:
   sudo systemctl status tailscaled
   
3. Reinstall if needed:
   sudo ./tailscale_setup.py

================================================================================
10. SECURITY CONSIDERATIONS
================================================================================

Access Control:
---------------
1. Use ACLs (Access Control Lists):
   - Configure in admin console
   - Restrict access between devices
   - Group devices by function

2. Enable shields-up on sensitive devices:
   tailscale up --shields-up

3. Regular audits:
   - Review connected devices monthly
   - Remove unused/old devices
   - Check ACL effectiveness

Key Management:
---------------
1. Key expiry:
   - Keys expire after 180 days by default
   - Re-authenticate when prompted
   - Consider disabling expiry for servers

2. Device authorization:
   - Approve new devices promptly
   - Remove unknown devices immediately

Exit Node Security:
-------------------
1. Only use trusted exit nodes
2. Understand your traffic routes through exit node owner
3. Consider running your own exit node
4. Monitor exit node usage

SSH Security:
-------------
1. Tailscale SSH bypasses traditional SSH keys
2. Uses Tailscale authentication
3. Can be more secure than password auth
4. Configure ACLs to control SSH access

Best Practices:
---------------
1. Keep Tailscale updated:
   sudo apt update && sudo apt upgrade tailscale
   
2. Use descriptive hostnames
3. Enable MagicDNS
4. Configure ACLs appropriately
5. Monitor connected devices
6. Use tags for device grouping
7. Enable audit logging in admin console
8. Regular security reviews

================================================================================
11. FILE LOCATIONS
================================================================================

Configuration:
--------------
settings.json                      : Suite configuration
/etc/default/tailscaled           : Tailscaled startup config

State Files:
------------
/var/lib/tailscale/               : Tailscale state directory
/var/lib/tailscale/tailscaled.state : Connection state

Logs:
-----
journalctl -u tailscaled          : Service logs
/var/log/tailscale/               : Additional logs (if configured)

Binaries:
---------
/usr/bin/tailscale                : Client binary
/usr/sbin/tailscaled              : Daemon binary

System:
-------
/etc/systemd/system/tailscaled.service : Service unit file
/etc/sysctl.d/99-tailscale.conf        : IP forwarding config

================================================================================
QUICK REFERENCE COMMANDS
================================================================================

Status & Information:
---------------------
tailscale status                   # Show connection status
tailscale status --peers           # Show all peers
tailscale ip                       # Show Tailscale IPs
tailscale version                  # Show version
tailscale netcheck                 # Test network connectivity

Connection:
-----------
sudo tailscale up                  # Connect/authenticate
sudo tailscale down                # Disconnect
sudo tailscale logout              # Logout completely

Configuration:
--------------
tailscale set --hostname=NAME      # Change hostname
tailscale set --exit-node=NODE     # Use exit node
tailscale set --exit-node=         # Stop using exit node
tailscale up --accept-routes       # Accept subnet routes
tailscale up --advertise-exit-node # Advertise as exit node
tailscale up --ssh                 # Enable Tailscale SSH

File Sharing:
-------------
tailscale file cp FILE HOST:       # Send file
tailscale file get DIR             # Receive files

Debugging:
----------
sudo ./tailscale_debug.py          # Run diagnostics
sudo journalctl -u tailscaled -f   # Watch logs
tailscale ping PEER                # Test connectivity
tailscale netcheck                 # Check network conditions

Service Management:
-------------------
sudo systemctl start tailscaled    # Start service
sudo systemctl stop tailscaled     # Stop service
sudo systemctl restart tailscaled  # Restart service
sudo systemctl status tailscaled   # Check status

================================================================================
ADMIN CONSOLE
================================================================================

Web Interface: https://login.tailscale.com/admin

Features:
- View all machines
- Approve/remove devices
- Configure ACLs
- Manage DNS
- Enable/disable features
- View audit logs
- Manage keys
- Configure tags

================================================================================
ADDITIONAL RESOURCES
================================================================================

Official Documentation:
  https://tailscale.com/kb/

Community Forum:
  https://forum.tailscale.com/

GitHub:
  https://github.com/tailscale/tailscale

Support:
  support@tailscale.com
