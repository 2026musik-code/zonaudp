#!/bin/bash

# ==============================================================================
# UDP Custom (ZIVPN Native) Auto-Install Script
# Repository: https://github.com/2026musik-code/zonaudp
# ==============================================================================

# Global Variables
BINARY_PATH="/usr/local/bin/udp-custom"
CONFIG_DIR="/etc/udp-custom"
CONFIG_FILE="$CONFIG_DIR/config.json"
SERVICE_FILE="/etc/systemd/system/udp-custom.service"
# Assumes the binary 'udp-custom' is uploaded to the root of the repo
BINARY_URL="https://raw.githubusercontent.com/2026musik-code/zonaudp/main/udp-custom"

# ANSI Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Helper Functions
function echo_title() {
    echo -e "${CYAN}==================================================${NC}"
    echo -e "${YELLOW}   $1${NC}"
    echo -e "${CYAN}==================================================${NC}"
}

function echo_success() {
    echo -e "${GREEN}[OK] $1${NC}"
}

function echo_error() {
    echo -e "${RED}[ERROR] $1${NC}"
}

function echo_info() {
    echo -e "${BLUE}[INFO] $1${NC}"
}

function check_root() {
    if [[ $EUID -ne 0 ]]; then
       echo_error "This script must be run as root"
       exit 1
    fi
}

function check_os() {
    if [[ -e /etc/debian_version ]]; then
        OS="debian"
        echo_info "Detected Debian/Ubuntu based OS"
    else
        echo_error "This script is intended for Debian or Ubuntu only."
        exit 1
    fi
}

function pause() {
    read -p "Press [Enter] key to continue..."
}

# Menu Functions (Placeholders)
function install_udp_custom() {
    echo_title "Install UDP Custom"

    # 1. Update & Install Dependencies
    echo_info "Updating repositories and installing dependencies..."
    # Suppress prompts
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y

    # Pre-configure iptables-persistent to avoid interactive prompt
    if ! command -v debconf-set-selections &> /dev/null; then
        apt-get install -y debconf-utils
    fi
    echo iptables-persistent iptables-persistent/autosave_v4 boolean true | debconf-set-selections
    echo iptables-persistent iptables-persistent/autosave_v6 boolean true | debconf-set-selections

    apt-get install -y wget net-tools iptables-persistent jq curl openssl

    # 2. Check Port 6000
    if netstat -tuln | grep -q ":6000 "; then
        echo_error "Port 6000 is already in use. Aborting."
        pause
        return
    fi

    # 3. Inputs
    read -p "Enter Obfs Key (e.g., zivpn): " obfs_key
    if [[ -z "$obfs_key" ]]; then obfs_key="zivpn"; fi

    read -p "Enter Initial Username: " username
    if [[ -z "$username" ]]; then echo_error "Username cannot be empty"; pause; return; fi

    read -p "Enter Password: " password
    if [[ -z "$password" ]]; then echo_error "Password cannot be empty"; pause; return; fi

    # 4. Download Binary
    echo_info "Downloading UDP Custom Binary..."
    if wget -O "$BINARY_PATH" "$BINARY_URL" 2>/dev/null; then
        echo_success "Binary downloaded successfully."
    else
        echo_error "Failed to download binary from $BINARY_URL"
        echo_error "File not found in repository. Please ensure 'udp-custom' is uploaded to your GitHub."

        # Interactive fallback
        while true; do
            echo -e "${YELLOW}Please choose an action:${NC}"
            echo -e "1) Enter an alternative URL"
            echo -e "2) Install a dummy binary (For testing/demo only)"
            echo -e "3) Abort installation"
            read -p "Selection: " bin_choice

            case $bin_choice in
                1)
                    read -p "Enter URL: " alt_url
                    if wget -O "$BINARY_PATH" "$alt_url" 2>/dev/null; then
                        echo_success "Binary downloaded from alternative URL."
                        break
                    else
                        echo_error "Failed to download from $alt_url"
                    fi
                    ;;
                2)
                    echo_info "Creating a dummy binary..."
                    echo '#!/bin/bash' > "$BINARY_PATH"
                    echo 'while true; do echo "UDP Custom (Dummy) Running with args: $@"; sleep 10; done' >> "$BINARY_PATH"
                    break
                    ;;
                3)
                    echo_error "Installation Aborted."
                    return
                    ;;
                *)
                    echo "Invalid Option."
                    ;;
            esac
        done
    fi
    chmod +x "$BINARY_PATH"

    # 5. Generate SSL Certificate (Required by ZIVPN Native)
    echo_info "Generating Self-Signed Certificate..."
    mkdir -p "$CONFIG_DIR"
    openssl req -new -newkey rsa:2048 -days 365 -nodes -x509 \
        -subj "/C=ID/ST=Jawa Barat/L=Bandung/O=ZIVPN/OU=IT/CN=zivpn" \
        -keyout "$CONFIG_DIR/server.key" -out "$CONFIG_DIR/server.crt" 2>/dev/null

    # 6. Create Config File (Native ZIVPN Format)
    # Using 'passwords' mode as seen in standard implementations
    cat <<EOF > "$CONFIG_FILE"
{
  "listen": ":6000",
  "cert": "$CONFIG_DIR/server.crt",
  "key": "$CONFIG_DIR/server.key",
  "obfs": "$obfs_key",
  "auth": {
    "mode": "passwords",
    "config": [
      "$username:$password"
    ]
  }
}
EOF

    # 7. Systemd Service
    echo_info "Creating Systemd Service..."
    cat <<EOF > "$SERVICE_FILE"
[Unit]
Description=UDP Custom Service
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$CONFIG_DIR
ExecStart=$BINARY_PATH -c $CONFIG_FILE
Restart=always
Environment=ZIVPN_LOG_LEVEL=info
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
NoNewPrivileges=true

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable udp-custom
    systemctl start udp-custom

    # 8. Iptables Redirect
    echo_info "Setting up Iptables..."
    # Clear existing rule to avoid duplicates
    iptables -t nat -D PREROUTING -p udp --dport 6000:19999 -j REDIRECT --to-ports 6000 2>/dev/null
    # Add new rule
    iptables -t nat -A PREROUTING -p udp --dport 6000:19999 -j REDIRECT --to-ports 6000

    # Save persistent
    netfilter-persistent save
    netfilter-persistent reload

    echo_success "Installation Complete!"
    pause
}

function manage_users() {
    while true; do
        clear
        echo_title "Manage Users"
        echo -e "${GREEN}1.${NC} Add User"
        echo -e "${GREEN}2.${NC} Remove User"
        echo -e "${GREEN}3.${NC} List Users"
        echo -e "${GREEN}0.${NC} Back to Main Menu"
        echo -e "${CYAN}==================================================${NC}"
        read -p "Select Option: " u_choice

        if [[ ! -f "$CONFIG_FILE" ]]; then
            echo_error "Config file not found. Install UDP Custom first."
            pause
            return
        fi

        case $u_choice in
            1)
                read -p "Enter New Username: " new_user
                if [[ -z "$new_user" ]]; then echo_error "Username cannot be empty"; pause; continue; fi

                read -p "Enter Password: " new_pass
                if [[ -z "$new_pass" ]]; then echo_error "Password cannot be empty"; pause; continue; fi

                # Check if user exists (checking prefix before :)
                if jq -e --arg u "$new_user" '.auth.config | any(startswith($u + ":"))' "$CONFIG_FILE" >/dev/null; then
                    echo_error "User $new_user already exists."
                    pause
                    continue
                fi

                # Add user in "user:pass" format
                jq --arg entry "$new_user:$new_pass" '.auth.config += [$entry]' "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
                echo_success "User added."
                systemctl restart udp-custom
                pause
                ;;
            2)
                echo_info "Current Users:"
                printf "%-20s %-20s\n" "Username" "Password"
                # Parse "user:pass" strings
                jq -r '.auth.config[]' "$CONFIG_FILE" | while IFS=":" read -r u p; do
                    printf "%-20s %-20s\n" "$u" "$p"
                done

                read -p "Enter Username to delete: " del_user
                # Check exist
                if jq -e --arg u "$del_user" '.auth.config | any(startswith($u + ":"))' "$CONFIG_FILE" >/dev/null; then
                     # Delete element starting with user:
                     jq --arg u "$del_user" '.auth.config |= map(select(startswith($u + ":") | not))' "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
                     echo_success "User $del_user deleted."
                     systemctl restart udp-custom
                else
                     echo_error "User not found."
                fi
                pause
                ;;
            3)
                echo_info "User List:"
                printf "%-20s %-20s\n" "Username" "Password"
                echo "----------------------------------------"
                jq -r '.auth.config[]' "$CONFIG_FILE" | while IFS=":" read -r u p; do
                    printf "%-20s %-20s\n" "$u" "$p"
                done
                pause
                ;;
            0)
                return
                ;;
            *)
                echo_error "Invalid Option"
                pause
                ;;
        esac
    done
}

function check_status() {
    echo_title "Service Status"
    if systemctl is-active --quiet udp-custom; then
        echo_success "Service is Active (Running)"
    else
        echo_error "Service is Inactive or Failed"
    fi

    echo_info "Recent Logs:"
    journalctl -u udp-custom -n 10 --no-pager
    pause
}

function optimize_speed() {
    echo_title "Optimize Speed (BBR & UDP Buffer)"

    # Backup sysctl.conf
    cp /etc/sysctl.conf /etc/sysctl.conf.bak

    # Add/Update settings
    SETTINGS=(
        "net.core.rmem_max = 16777216"
        "net.core.wmem_max = 16777216"
        "net.core.rmem_default = 262144"
        "net.core.wmem_default = 262144"
        "net.ipv4.udp_mem = 8192 32768 16777216"
        "net.ipv4.udp_rmem_min = 16384"
        "net.ipv4.udp_wmem_min = 16384"
        "net.core.netdev_max_backlog = 5000"
        "net.ipv4.tcp_congestion_control = bbr"
        "net.core.default_qdisc = fq"
    )

    for setting in "${SETTINGS[@]}"; do
        key=$(echo "$setting" | cut -d= -f1 | xargs)
        # Remove existing line matching key to avoid duplicates
        sed -i "/^$key/d" /etc/sysctl.conf
        # Append new setting
        echo "$setting" >> /etc/sysctl.conf
    done

    sysctl -p
    echo_success "Optimization applied!"
    pause
}

function uninstall_udp_custom() {
    echo_title "Uninstall UDP Custom"
    read -p "Are you sure you want to uninstall? (y/N): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        return
    fi

    echo_info "Stopping Service..."
    systemctl stop udp-custom
    systemctl disable udp-custom
    rm "$SERVICE_FILE"
    systemctl daemon-reload

    echo_info "Removing Files..."
    rm -rf "$CONFIG_DIR"
    rm -f "$BINARY_PATH"

    echo_info "Removing Iptables Rules..."
    iptables -t nat -D PREROUTING -p udp --dport 6000:19999 -j REDIRECT --to-ports 6000 2>/dev/null
    netfilter-persistent save
    netfilter-persistent reload

    echo_success "Uninstall Complete!"
    pause
}

# Main Menu
function show_menu() {
    clear
    echo -e "${CYAN}==================================================${NC}"
    echo -e "${YELLOW}       UDP Custom (ZIVPN Native) Manager         ${NC}"
    echo -e "${CYAN}==================================================${NC}"
    echo -e "${GREEN}1.${NC} Install UDP Custom"
    echo -e "${GREEN}2.${NC} Manage Users"
    echo -e "${GREEN}3.${NC} Check Service Status"
    echo -e "${GREEN}4.${NC} Optimize Speed (BBR & Buffer)"
    echo -e "${GREEN}5.${NC} Uninstall"
    echo -e "${GREEN}0.${NC} Exit"
    echo -e "${CYAN}==================================================${NC}"
    read -p "Select Option: " choice

    case $choice in
        1) install_udp_custom ;;
        2) manage_users ;;
        3) check_status ;;
        4) optimize_speed ;;
        5) uninstall_udp_custom ;;
        0) exit 0 ;;
        *) echo_error "Invalid option"; pause ;;
    esac
}

# Entry Point
check_root
check_os

while true; do
    show_menu
done
