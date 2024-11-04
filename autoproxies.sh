#!/bin/bash

# Get Values from config file
config_file="autoproxies.conf"
saved_timestamp=$(grep '^last_commit=' "$config_file" | cut -d'=' -f2)

#echo "Saved timestamp: $saved_timestamp"

# Define the proxies file

PROXY_FILE=$(pwd)"/proxies_list.txt"

###############################################################################
##  OPTIONS PART
###############################################################################

# Display help message
function help() {
    echo "Usage: $0 [options...]"
    echo "  -h, --help              display this help message"
    echo "  -t, --tor               add Tor sockets to proxy list (need root privileges)"
    echo "  -k, --keep              keep the older proxy files"
    echo "  -f, --force             force download of new proxies"
    echo "  -m, --mode <value>      choose mode of filtering proxies"
    echo "             1 = Only really fast proxies but limited number"
    echo "             2 = (Default) Between 1 and 3. Good balance between speed and randomness"
    echo "             3 = More proxies (and increase randomness) but maybe slower"
}

# Initialize variables
is_tor=false
mode=2
keep=false
force=false

# Parse options
while [[ $# -gt 0 ]]; do
    case $1 in
    -h | --help) help
        exit 0 ;;
    -t | --tor) is_tor=true ;;
    -k|--keep) keep=true ;;
    -f|--force) force=true ;;
    -m|--mode) 
        if [[ -n "$2" && "$2" != -* ]]; then
            mode="$2"
            if [[ $mode -lt 1 || $mode -gt 3 ]]; then
                echo "Error : mode must be between 1 and 3" >&2
                exit 1
            fi
            shift
        else
            echo "Error : $1 requires an argument" >&2
            exit 1
        fi;;
    *) echo "Invalid option: $1"
        help
        exit 1 ;;
    esac
    shift
done

###############################################################################
##  TOR PART (if is_tor)
###############################################################################

if $is_tor; then

    # Check if user as root privileges
    if [[ $EUID -ne 0 ]]; then
        echo "The script must be run as root if you want to use Tor."
        exit 1
    fi

    # Check if tor is installed
    if ! systemctl list-unit-files --type=service | grep ^tor.service; then
        echo "Tor is not installed.
        Please install it first and run this script again."
        exit 1
    fi

    # Run tor service if not running
    is_active=$(sudo systemctl is-active tor)
    if [[ $is_active != "active" ]]; then
        echo "Starting tor service..."
        sudo systemctl start tor
    fi
fi

###############################################################################
##  Bootstrap New Proxies
###############################################################################

if ! $keep; then
    # Get the timestamp of the last commit made on github
    last_commit=$(curl -s https://api.github.com/repos/TheSpeedX/PROXY-List/commits | jq -r '.[0].commit.committer.date')
    last_commit_timestamp=$(date -d "$last_commit" +%s)

    #check if this timestamp is newer than the saved timestamp
    if [[ $last_commit_timestamp -gt $saved_timestamp || $force == true ]]; then
        NewProxies=true
        echo "Downloading new proxies..."
        curl -s https://raw.githubusercontent.com/TheSpeedX/PROXY-List/master/socks5.txt -o $PROXY_FILE
        curl -s https://raw.githubusercontent.com/TheSpeedX/PROXY-List/master/socks4.txt >> $PROXY_FILE
        curl -s https://raw.githubusercontent.com/TheSpeedX/PROXY-List/master/http.txt >> $PROXY_FILE

        # Update the timestamp in the config file
        sed -i "s/^last_commit=.*/last_commit=$last_commit_timestamp/" $config_file
    else
        NewProxies=false
    fi
else
    NewProxies=false
fi

# Check if the proxies file exists or is empty
if [[ ! -f $PROXY_FILE || ! -s $PROXY_FILE ]]; then
    echo "Proxy file not found or empty: $PROXY_FILE"
    exit 1
fi

###############################################################################
##  Ensure proxies are alive and working if they are NewProxies
###############################################################################

if $NewProxies; then

    OutputFile="tmp.txt"

    #Module threading and timeout depending on speed and number of proxies wanted
    case $mode in
        1) 
            th=45
            t=1 ;;
        2) # Default
            th=30
            t=2;;
        3) 
            th=30
            t=5 ;;
    esac

    echo "Checking proxies are working..."
    python3 socker.py -i $PROXY_FILE -o $OutputFile -th $th -t $t

    # Merge the new proxies into the proxies file
    echo "$(cat $OutputFile)" > $PROXY_FILE
    rm $OutputFile

fi
###############################################################################
##  PROXYCHAINS PART
###############################################################################

# List of commands to exclude from proxychains
EXCLUDE_COMMANDS=("cd" "ls" "pwd")

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RESET='\033[0m' 

while true; do

    # Set the prompt with colors
    PS1="${YELLOW}$(whoami)@Autoproxies${RESET}:${BLUE}$(pwd)${RESET}$ "

    # Select three random proxies
    RANDOM_PROXIES=($(shuf -n 3 $PROXY_FILE))

    # Create the proxychains configuration for the selected proxies
    PROXYCHAINS_CONFIG="[proxychains]
        strict_chain
        proxy_dns
        [ProxyList]
        # other proxies added
        "

    if $is_tor; then
        PROXYCHAINS_CONFIG+="\nsocks4 127.0.0.1 9050\n"
    fi

    for PROXY in "${RANDOM_PROXIES[@]}"; do
        PROXY_CLEAN="${PROXY//:/ }" # replace : with a space
        PROXYCHAINS_CONFIG+="socks4 $PROXY_CLEAN\n"
    done

    # Write the configuration to a temporary proxychains configuration file
    TEMP_CONFIG=$(mktemp)
    echo -e "$PROXYCHAINS_CONFIG" > $TEMP_CONFIG

    # Prompt the user to enter the command to run
    echo -n -e "$PS1"
    read -e USER_COMMAND

    # End program if exit is entered
    if [[ $USER_COMMAND == "exit" ]]; then
        echo "Bye."
        exit 0
    fi

    # Add the command to the history
    if [[ -n "$USER_COMMAND" ]]; then
        history -s "$USER_COMMAND"
    fi

    # Check if the command starts with any excluded command
    run_pc=true
    for cmd in "${EXCLUDE_COMMANDS[@]}"; do
        if [[ "$USER_COMMAND" == "$cmd"* ]]; then
            run_pc=false
            break
        fi
    done

    if $run_pc; then
        # Display selected proxies and the command
        echo "Using the following proxies:"
        printf "%s\n" "${RANDOM_PROXIES[@]}"
        echo ""

        # Execute the command with proxychains using the temporary config
        proxychains -f "$TEMP_CONFIG" $USER_COMMAND
    else
        # Execute the command directly
        $USER_COMMAND
    fi

    # Clean up
    rm $TEMP_CONFIG
done
