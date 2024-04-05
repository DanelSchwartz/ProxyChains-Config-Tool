# ProxyChains Configuration Tool

This repository contains a Bash script named `proxy_manager.sh` designed to manage proxy configurations for ProxyChains. It allows users to add, remove, and list proxies in the `/etc/proxychains.conf` file easily.

## Features

- **Add a Proxy**: Users can add new proxy configurations, including HTTP, HTTPS, SOCKS4, and SOCKS5 proxies.
- **Remove a Proxy**: Users can remove specific proxy configurations based on proxy type, IP, and port.
- **List Proxies**: Displays all currently configured proxies in `/etc/proxychains.conf`, excluding comments and empty lines.

## Requirements

- The script must be run with root privileges to modify the `/etc/proxychains.conf` file.
- Bash shell.

## Usage

1. Clone this repository or download `proxy_manager.sh` directly.
2. Give the script executable permissions:
```bash
chmod +x proxy_manager.sh
```
3. Run the script with root privileges:
```bash
sudo ./proxy_manager.sh
```
4. Follow the on-screen menu to manage your ProxyChains configurations.

## Contributing

Contributions are welcome! Feel free to submit pull requests or create issues for bugs, feature requests, or improvements.

## License

This project is licensed under the MIT License - see the LICENSE file for details.
