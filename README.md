# scan-ports

#### How to install:

```bash
cd /tmp
git clone https://github.com/Zeroberto86/scan-ports.git
cd scan-ports
sudo cp scan-ports.sh /usr/local/bin/scan-ports
sudo chmod +x /usr/local/bin/scan-ports
```

#### How to use:

`scan-ports <dns_name or ip> <first port> <last port>`

> Example:

```bash
scan-ports 192.168.0.1 22 135
```