## Installation Instructions

# 1. Save the script
```bash sudo nano /usr/local/bin/rsync-wrapper ```
# 2. Paste all three parts above into the file

# 3. Make it executable
```bash sudo chmod +x /usr/local/bin/rsync-wrapper ```

# 4. Test it
```bash rsync-wrapper --help ```

# 5. Optional: Create a shorter alias
```bash
echo "alias rsm='rsync-wrapper'" >> ~/.bashrc
source ~/.bashrc
```

## Usage Examples
### Interactive mode (prompts for paths)
rsync-wrapper

### Quick local copy
rsync-wrapper /source/ /destination/

### Network copy with bandwidth limit
rsync-wrapper --bandwidth 5000 /data/ user@server:/backup/

# Mirror with delete and stats
rsync-wrapper --delete --stats /source/ /destination/

# Resume interrupted transfer
rsync-wrapper --resume

# Archive mode for many small files
rsync-wrapper --archive /project/ user@server:/backup/

# Exclude patterns
rsync-wrapper --exclude "*.log" --exclude "node_modules" /app/ /backup/

# Dry-run only (no confirmation)
rsync-wrapper --dry-run /source/ /destination/
