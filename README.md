# P5 Check (script)

Check local P5 server is files are archived. 
Checks if P5 has a "handle" for a file at a path

Files not archived will be listed in a text file.
Files archived by P5 will be checked for relevant metadata and listed in a csv (spreadsheet) file.

P5 Check (Dialog) uses the swiftDialog project for notifications of script checking progress
P5 Check (Perl) uses a perl code block to better handle filenames with commas better

# P5 Archive Manager (app)
Check P5 if a folder is archived on a remote P5 server. 
Saves credentials in the macOS keychain
![P5ArchiveManager-UI](https://github.com/user-attachments/assets/55d39389-f5ae-4026-8579-b1b1cfab8fab)

# P5 Archive Checker (app)
Check P5 if a folder is archived on a local P5 server.

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
- Archiware P5 server that will be checked is local
- 'nsdchat' available at /usr/local/aw/bin/nsdchat
## Known Issues
- FIXED in v.1.6 -- If the file names contain commas then the resulting CSV file will be messy. 
- FIXED in v.1.6 -- If the app stays at 0% checking then quit the app and try again.
![P5 Archive Checker Help Not Archived](https://github.com/user-attachments/assets/063556fb-7e5a-4124-ac6c-20c497f7f7a4)
