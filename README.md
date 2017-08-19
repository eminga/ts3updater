# TeamSpeak 3 Server Installer and Updater
A lightweight script to install or update a TeamSpeak 3 server on Linux or FreeBSD. Should also work on macOS (currently untested).

## Dependencies
* curl
* jq (https://stedolan.github.io/jq/download/)

All other dependencies (cd, cut, echo, grep, mktemp, sed, shasum/sha256/sha256sum, tar, uname, wc, and an sh-compatible shell) are installed by default on most systems.

## How to use
### Install a new TeamSpeak 3 server
Place the script where you want to install the TS server, make it executable with `chmod +x ts3updater.sh` and run it with `./ts3updater.sh`. After the installation, the script moves itself into the installation folder. Run it from there whenever you want to update the server.

### Update an existing TeamSpeak 3 server installation
Place the script in the directory of your existing TS installation. This means, the script has to be in the same directory as for example the file `ts3server_startscript.sh`. Make it executable with `chmod +x ts3updater.sh` and run it with `./ts3updater.sh`.

If you use TSDNS, make sure the service is stopped before you execute this script.

## What this script does
1. Determine the OS and CPU architecture
2. Check if there is an existing installation and determine its version
3. Check for newer versions
4. If there is a newer version:
    1. Download the new version
    2. Check whether the checksum is correct
    3. Stop running servers
    4. Extract the updated files into the server directory
    5. Start the server
