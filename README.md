# p5ArchiveCheck
Check P5 if a folder is archived with a simple script or app

# P5 Archive Checker – User Guide
## Overview
P5 Archive Checker is a macOS application that verifies whether files in a selected folder
have been archived using Archiware P5. Users simply drag and drop a folder onto the app
to begin an automated verification process.
## How to Use
1. Open the P5 Archive Checker application.
2. Drag any folder onto the main window.
3. The verification will begin automatically.
4. Watch the live progress updates.
5. When complete, open the generated:
- Summary report
- Archive CSV report
- Full log file
- Backup archive (optional)
## Output Files
- A list of files NOT archived.
- A CSV listing all archived files with metadata.
- A full log of the process.
- A backup tar.gz of all technical intermediate data.
## Requirements
- macOS
- Archiware P5 installed locally
- 'nsdchat' available at /usr/local/aw/bin/nsdchat
## Troubleshooting
- If the app reports missing P5 tools, reinstall Archiware P5.
- Ensure the folder is readable and not on a restricted volume.
