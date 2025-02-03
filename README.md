# A simple LAMP + WordPress installer/uninstaller on Fedora


A simple script that allows you to install or remove the necessary packages to run WordPress ( 🇮🇹 Italian version ) on Fedora desktop.

It has been tested on Fedora 41 out-of-the-box, without the LAMP stack already installed (Linux, Apache, MySQL/MariaDB, PHP).

## Configuration
In the repository you can find a `.env-sample` file that you need to edit with your params and rename in `.env`.
```
DB_NAME=my_database
DB_USER=my_db_user
DB_PASS=my_db_password
DB_ROOT_PASS=root_password
```

Make sure that the `lampw-manages.sh` file and the `.env` file are in the same folder!

From the terminal, run:
```bash
sudo chmod +x lampw-manages.sh
sudo ./lampw-manages.sh
```

**Important:** The script must be run as root or with sudo because it needs to access restricted directories ( such as `/var/www/html` ) and automatically install all necessary packages.

## Packages list
This script will install/remove the following packages with their dependencies.
|Packages         | Installed | Removed |
|---              |:-:        |:-:      |
| httpd           | ✔️ | ✔️ |
| mariadb-server  | ✔️ | ✔️ |
| mariadb         | ✔️ | ✔️ |
| php             | ✔️ | ✔️ |
| php-mysqlnd     | ✔️ | ✔️ |
| php-fpm         | ✔️ | ✔️ |
| php-json        | ✔️ | ✔️ |
| php-xml         | ✔️ | ✔️ |
| php-curl        | ✔️ | ✔️ |
| php-mbstring    | ✔️ | ✔️ |
| php-gd          | ✔️ | ✔️ |
| php-intl        | ✔️ | ✔️ |
| php-soap        | ✔️ | ✔️ |
| php-zip         | ✔️ | ✔️ |
| curl            | ✔️ | ✖️ |
| wget            | ✔️ | ✖️ |
| zip             | ✔️ | ✖️ |
| unzip           | ✔️ | ✖️ |

***
### Tested on 
![Static Badge](https://img.shields.io/badge/Fedora_41-%2351a2da?style=flat&logo=fedora&logoColor=%23ffffff)