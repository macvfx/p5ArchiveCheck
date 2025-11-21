# P5 Check (script)

Check local P5 server if selected files in a folder at a path are archived. 

## Overview 
- The scripts creates a list of files and checks if P5 has a "handle" for a file at a path
- Files not archived will be listed in a text file.
- Files archived by P5 will be checked for relevant metadata and listed in a csv (spreadsheet) file.
- P5 Check (Dialog) uses the swiftDialog project for notifications of script checking progress.
- P5 Check (Perl) uses a perl code block to better handle filenames with commas.

# P5 Archive Manager (app)
Check P5 if a folder is archived on a remote P5 server. 

## Overview
P5 Archive Manager is a macOS application that verifies whether files in a selected folder
have been archived by Archiware P5 in a remote P5 server in the Default Archive index.
## How to Use
1. Open the P5 Archive Manager application.
2. Add a remote P5 server with "Managed Servers"
3. Select a server to use.
4. Drag any folder onto the main window.
5. Click on "Run Verification Check" to begin verification.
6. Note: You can drop files to check then select a server, which allows you to check various servers. 
7. Watch the live progress updates.
8. When complete, the csv of archived files and their metadata, or the list of files not archived, are listed in the app so you can open and inspect as needed
## Output Files
- A list of files NOT archived (if any).
- A CSV listing all archived files with metadata.
- A full log of the process.
- A backup tar.gz of all temp intermediate data fetched from P5.
## Requirements
- macOS 14.6 minimum
- Archiware P5 server that will be checked is local
- Files archived in Default Archive index. 
- 'nsdchat' available at /usr/local/aw/bin/nsdchat

## Changelog And Known Issues
- FIXED in 2.4 -- Adding a new server would not show up until you left that section. Thanks to David Fox!
- CHANGED in 2.4 -- Text file of un-archived items or the csv of archived files no longer auto-open. Also thanks David.
- CHANGED in 2.4 -- minimum macOS is now 14.6 (this was required by a swift change to fix the server add bug)
- KNOWN ISSUES -- Only work with files in the Default Archive index.

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
5. When complete, opens automatically the generated:
- Archive CSV report with metadata
- Or the files not archived
## Output Files
- A list of files NOT archived.
- A CSV listing all archived files with metadata.
- A full log of the process.
- A backup tar.gz of all technical intermediate data.
## Requirements
- macOS
- Archiware P5 server that will be checked is local
- Files archived in Default Archive index. 
- 'nsdchat' available at /usr/local/aw/bin/nsdchat
## Known Issues
- FIXED in v.1.6 -- If the file names contain commas then the resulting CSV file will be messy. 
- FIXED in v.1.6 -- If the app stays at 0% checking then quit the app and try again.
![P5 Archive Checker Help Not Archived](https://github.com/user-attachments/assets/063556fb-7e5a-4124-ac6c-20c497f7f7a4)
