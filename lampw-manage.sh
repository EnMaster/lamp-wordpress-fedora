#!/bin/bash

# Check if you run as root or with sudo
check_root() {
  if [ "$EUID" -ne 0 ]; then
    echo "This script must be run as root or with sudo."
    exit 1
  fi
}

# Load .env vars. Remember to create a .env file or rename the .env-sanple in the same directory as this script
load_env() {
  if [ -f .env ]; then
    export $(cat .env | xargs)
  else
    echo ".env file not found!"
    exit 1
  fi
}

# LAMP installer
install_lamp() {
  echo "Installing LAMP stack..."
  
  dnf update -y

  # Apache
  dnf install httpd -y
  systemctl start httpd
  systemctl enable httpd

  # MariaDB
  dnf install mariadb-server mariadb -y
  systemctl start mariadb
  systemctl enable mariadb

  # Configure the database and user
  mysql -e "SET PASSWORD FOR 'root'@'localhost' = PASSWORD('$DB_ROOT_PASS')"
  mysql -e "DROP USER IF EXISTS ''@'localhost'"
  mysql -e "DROP USER IF EXISTS ''@'$(hostname)'"
  mysql -e "DROP DATABASE IF EXISTS test"
  mysql -e "FLUSH PRIVILEGES"

  DB_EXISTS=$(mysql -u root -p$DB_ROOT_PASS -e "SHOW DATABASES LIKE '$DB_NAME'" | grep "$DB_NAME" > /dev/null; echo "$?")
  if [ $DB_EXISTS -eq 0 ]; then
    echo "Database $DB_NAME already exists, skipping creation."
  else
    mysql -u root -p$DB_ROOT_PASS -e "CREATE DATABASE $DB_NAME"
  fi

  USER_EXISTS=$(mysql -u root -p$DB_ROOT_PASS -e "SELECT User FROM mysql.user WHERE User = '$DB_USER'" | grep "$DB_USER" > /dev/null; echo "$?")
  if [ $USER_EXISTS -eq 0 ]; then
    echo "User $DB_USER already exists, skipping creation."
  else
    mysql -u root -p$DB_ROOT_PASS -e "CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS'"
    mysql -u root -p$DB_ROOT_PASS -e "GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost'"
    mysql -u root -p$DB_ROOT_PASS -e "FLUSH PRIVILEGES"
  fi

  # PHP
  dnf install php php-mysqlnd php-fpm php-json php-xml php-curl php-mbstring php-gd php-intl php-soap php-zip -y

  # In the case of missing basic tools
  dnf install curl wget zip unzip -y

  
  systemctl restart httpd

  echo "LAMP stack installed successfully."
}

# Configure SELinux to make WordPress work
configure_selinux() {
  echo "Configuring SELinux..."
  setsebool -P httpd_can_network_connect on  
  echo "SELinux configured successfully."
}

# Download Wordpress latest version in Italian :) 
download_wordpress() {
  echo "Downloading and extracting WordPress..."
  
  FILE_PATH="/tmp/latest-it_IT.zip"
  USER_HOME=$(eval echo ~${SUDO_USER})
  DEST_DIR="$USER_HOME/wordpress"

  if [ -f "$FILE_PATH" ]; then
    rm "$FILE_PATH"
  fi

  wget https://it.wordpress.org/latest-it_IT.zip -O "$FILE_PATH"

  if [ -d "$DEST_DIR" ]; then
    rm -rf "$DEST_DIR"
  fi

  unzip "$FILE_PATH" -d "$USER_HOME"
  rm "$FILE_PATH"
  
  echo "WordPress downloaded and extracted successfully."
}

# Configure Wordpress files
setup_wp_config() {
  echo "Setting up wp-config.php..."
  
  USER_HOME=$(eval echo ~${SUDO_USER})
  WP_CONFIG_SAMPLE="$USER_HOME/wordpress/wp-config-sample.php"
  WP_CONFIG="$USER_HOME/wordpress/wp-config.php"

  if [ -f "$WP_CONFIG" ]; then
    echo "wp-config.php already exists and will not be modified."
  else
    cp "$WP_CONFIG_SAMPLE" "$WP_CONFIG"
    sed -i "s/database_name_here/$DB_NAME/" "$WP_CONFIG"
    sed -i "s/username_here/$DB_USER/" "$WP_CONFIG"
    sed -i "s/password_here/$DB_PASS/" "$WP_CONFIG"
    echo "wp-config.php created and configured successfully."
  fi
}

# Copy wordpress in the Apache folder
copy_wordpress_files() {
  echo "Copying WordPress files to /var/www/html/..."
  
  USER_HOME=$(eval echo ~${SUDO_USER})
  DEST_DIR="/var/www/html"

  cp -r $USER_HOME/wordpress/* $DEST_DIR
  chown -R apache:apache $DEST_DIR
  chmod -R 755 $DEST_DIR
  
  echo "WordPress files copied successfully."
}

print_versions() {
  BLUE='\033[0;34m'
  GREEN='\033[0;32m'
  RED='\033[0;31m'
  NC='\033[0m'

  check_service_status() {
    if systemctl is-active --quiet "$1"; then
      echo -e "${GREEN}running${NC}"
    else
      echo -e "${RED}stopped${NC}"
    fi
  }

  printf "%-20s %-20s %-10s\n" "Program" "Version" "Status"
  printf "%-20s ${BLUE}%-20s${NC} %-10s\n" "Apache" "$(httpd -v | grep -oP '(?<=Server version: Apache/)[^ ]*')" "$(check_service_status httpd)"
  printf "%-20s ${BLUE}%-20s${NC} %-10s\n" "MySQL (MariaDB)" "$(mysql --version | grep -oP '(?<=Distrib )[^ ]*')" "$(check_service_status mariadb)"
  printf "%-20s ${BLUE}%-20s${NC} %-10s\n" "PHP" "$(php -v | grep -oP '^PHP [^ ]*' | cut -d ' ' -f 2)" "$(check_service_status php-fpm)"
}
# ---------------------------------------------------
# Functions to delete all packaes and wordpress files and DB
# ---------------------------------------------------

# Uninstall packages
remove_packages() {
  echo "Removing installed packages..."

  dnf remove httpd -y
  dnf remove mariadb-server mariadb -y
  dnf remove php php-mysqlnd php-fpm php-json php-xml php-curl php-mbstring php-gd php-intl php-soap php-zip -y
}

# Delete folders and files
remove_files_directories() {
  echo "Removing created files and directories..."
  
  USER_HOME=$(eval echo ~${SUDO_USER})
  rm -rf "$USER_HOME/wordpress"
  rm -rf /var/www/html/*
  rm -f "$USER_HOME/.env"
}
# Re-enable SELinux
restore_selinux() {
  echo "Restoring SELinux configuration..."
  setsebool -P httpd_can_network_connect off
}

# Stop and disable services
stop_disable_services() {
  echo "Stopping and disabling services..."
  
  systemctl stop httpd
  systemctl disable httpd
  systemctl stop mariadb
  systemctl disable mariadb
  systemctl stop php-fpm
  systemctl disable php-fpm
}

# Drop user and database
remove_database() {
  echo "Removing the associated database..."
  
  mysql -u root -p$DB_ROOT_PASS -e "DROP DATABASE IF EXISTS $DB_NAME"
  mysql -u root -p$DB_ROOT_PASS -e "DROP USER IF EXISTS '$DB_USER'@'localhost'"
  mysql -u root -p$DB_ROOT_PASS -e "FLUSH PRIVILEGES"
  
  echo "Database and MySQL user removed successfully."
}

ask_user() {
  echo "Do you want to install or remove the LAMP stack + WordPress?"
  echo "1) Install"
  echo "2) Remove"
  read -p "Select an option [1-2]: " choice

  case $choice in
    1)
      echo "Installing the LAMP stack + WordPress..."
      check_root
      load_env
      install_lamp
      configure_selinux
      download_wordpress
      setup_wp_config
      copy_wordpress_files
      print_versions
      echo "LAMP and Wordpress installed."
      ;;
    2)
      echo "Removing the LAMP stack + WordPress..."
      check_root
      load_env
      remove_database
      stop_disable_services
      remove_packages
      remove_files_directories
      restore_selinux
      echo "All packages, configurations, and created files have been removed."
      ;;
    *)
      echo "Invalid option. Run the script again and select a valid option [ 1 or 2 ]."
      exit 1
      ;;
  esac
}

ask_user