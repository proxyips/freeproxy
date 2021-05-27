#!/bin/bash
#The Server Pubilc IP Address  !!! MUST CHANGE !!! 
SERVER_IP=1.1.1.1
#The public IP that you want to access your proxy !!! MUST CHANGE !!!
ACCESS_IP=2.2.2.2

# API Access to Proxy Settings !!! MUST CHANGE !!!
API_USER=change_user
API_PASSWORD=change_password

# Public proxy country
COUNTRY=""

# Installing all the needed tools and tor
GO_VERSION=1.16.3
apt update && apt upgrade -y
apt install -y apt-transport-https

rm /etc/apt/sources.list.d/tor.list
echo deb https://deb.torproject.org/torproject.org stretch main >> /etc/apt/sources.list.d/tor.list
curl https://deb.torproject.org/torproject.org/A3C4F0F979CAA22CDBA8F512EE8CBC9E886DDD89.asc | gpg --import
gpg --export A3C4F0F979CAA22CDBA8F512EE8CBC9E886DDD89 | apt-key add -

apt update && apt upgrade -y
apt install -y git unzip curl wget build-essential tor deb.torproject.org-keyring

mkdir -p /opt/tmp /opt/src /opt/go/bin /opt/bin
wget https://storage.googleapis.com/golang/go${GO_VERSION}.linux-amd64.tar.gz -O /opt/tmp/go${GO_VERSION}.linux-amd64.tar.gz

tar -C /opt/ -xzf /opt/tmp/go${GO_VERSION}.linux-amd64.tar.gz
chmod +x /opt/go/bin/*
ln -s /opt/go/bin/* /bin/
rm /opt/tmp/go${GO_VERSION}.linux-amd64.tar.gz

rm golang.conf
cat << EOF >> golang.env
export GOPATH=/opt/src/ 
export GOBIN=/opt/go/bin 
export PATH=/opt/go/bin:$PATH 
export GO_VERSION=${GO_VERSION} 
export GOPROXY=direct 
export GOSUMDB=off
EOF
cat golang.env >> $HOME/.profile
export GOPATH=/opt/src/ 
export GOBIN=/opt/go/bin 
export PATH=/opt/go/bin:$PATH 
export GO_VERSION=${GO_VERSION} 
export GOPROXY=direct 
export GOSUMDB=off

# git config --global url.git@github.com:.insteadOf https://github.com/
# git config --global url.git@gitlab.com:.insteadOf https://gitlab.com/

git clone https://github.com/yyyar/gobetween.git
cd gobetween && make
cd ~
cp $HOME/gobetween/bin/gobetween /opt/bin/
chmod +x /opt/bin/gobetween && ln -s /opt/bin/gobetween /bin/gobetween

apt-get autoclean && apt-get autoremove 
rm -rf /tmp/* /var/lib/apt/lists/* /var/tmp/*

gobetween --version

git clone https://github.com/nadoo/glider.git
cd glider && go build -v -ldflags "-s -w" && cp glider /opt/bin/
chmod +x /opt/bin/glider && ln -s /opt/bin/glider /bin/glider

git clone https://github.com/proxyips/proxyupdater.git
cd proxyupdater && go build -o /opt/bin/proxyupdater proxyupdater/main.go 
chmod +x /opt/bin/proxyupdater && ln -s /opt/bin/proxyupdater /bin/proxyupdater

echo "*/15 * * * * /opt/bin/proxyupdater publicproxy -f /opt/gobetween/gobetween.json -c ${COUNTRY}" >> /etc/crontab

mkdir -p /opt/glider
rm /opt/glider/glider.conf
cat << EOF >> /opt/glider/glider.conf
# Verbose mode, print logs
verbose=False

listen=127.0.0.1:9051

forward=socks5://127.0.0.1:9050
EOF

cat << EOF >> /etc/systemd/system/gobetween.service
[Unit]
Description=Gobetween
Documentation=https://gobetween.io/

[Service]
User=www-data
Group=www-data
WorkingDirectory=/opt/gobetween/
LimitNOFILE=32786
PIDFile=/run/gobetween.pid
ExecStart=/bin/gobetween --format json from-file /opt/gobetween/gobetween.json
ExecReload=/usr/bin/pkill gobetween
PermissionsStartOnly=true

[Install]
WantedBy=multi-user.target
EOF
cat << EOF >> /etc/systemd/system/tor.service
[Unit]
Description=Tor
Documentation=https://torproject.org/

[Service]
User=www-data
Group=www-data
LimitNOFILE=32786
PIDFile=/run/tor.pid
ExecStart=/usr/bin/tor
ExecReload=/usr/bin/pkill tor
PermissionsStartOnly=true

[Install]
WantedBy=multi-user.target
EOF
cat << EOF >> /etc/systemd/system/glider.service
[Unit]
Description=Glider

[Service]
User=www-data
Group=www-data
WorkingDirectory=/opt/glider
LimitNOFILE=32786
PIDFile=/run/glider.pid
ExecStart=/opt/bin/glider -config /opt/glider/glider.conf
ExecReload=/usr/bin/pkill glider
PermissionsStartOnly=true

[Install]
WantedBy=multi-user.target
EOF

mkdir -p /opt/gobetween/

cat << EOF >> /opt/gobetween/gobetween.json
{
    "logging": {
        "level": "debug",
        "output": "/opt/gobetween/log.json",
        "format": "json"
    },
    "api": {
        "enabled": true,
        "bind": "${SERVER_IP}:8080",
        "basic_auth": {
            "login": "${API_USER}",
            "password": "${API_PASSWORD}"
        },
        "cors": false
    },
    "metrics": {
        "enabled": true,
        "bind": "127.0.0.1:8010"
    },
    "defaults": {
        "max_connections": null,
        "client_idle_timeout": null,
        "backend_idle_timeout": null,
        "backend_connection_timeout": null
    },
    "acme": null,
    "profiler": null,
    "servers": {
        "tor_proxies":{
            "max_connections": 150,
            "client_idle_timeout": "130s",
            "backend_idle_timeout": "0",
            "backend_connection_timeout": "0",
            "bind": "${SERVER_IP}:8090",
            "protocol": "tcp",
            "balance": "roundrobin",
            "sni": null,
            "tls": null,
            "backends_tls": null,
            "udp": null,
            "access": {
                "default": "deny",
                "rules": [
                    "allow ${ACCESS_IP}"
                ]
            },
            "proxy_protocol": null,
            "discovery": {
                "kind": "static",
                "failpolicy": "keeplast",
                "interval": "0",
                "timeout": "0",
                "static_list": [
                "127.0.0.1:9051",
                "127.0.0.1:9051"
                ]
            },
            "healthcheck": {
                "kind": "ping",
                "interval": "15m",
                "passes": 2,
                "fails": 1,
                "timeout": "1s",
                "initial_status": "healthy"
            }
        },
        "public_proxies": {
            "max_connections": 150,
            "client_idle_timeout": "130s",
            "backend_idle_timeout": "0",
            "backend_connection_timeout": "0",
            "bind": "${SERVER_IP}:8091",
            "protocol": "tcp",
            "balance": "roundrobin",
            "sni": null,
            "tls": null,
            "backends_tls": null,
            "udp": null,
            "access": {
                "default": "deny",
                "rules": [
                    "allow ${ACCESS_IP}"
                ]
            },
            "proxy_protocol": null,
            "discovery": {
                "kind": "static",
                "failpolicy": "setempty",
                "interval": "5s",
                "timeout": "2s",
                "static_list": null
            },
            "healthcheck": {
                "kind": "ping",
                "interval": "3s",
                "passes": 2,
                "fails": 1,
                "timeout": "1s",
                "initial_status": "healthy"
            }
        }
    }
}
EOF
chown -R www-data:www-data /opt/gobetween
chown -R www-data:www-data /opt/glider
systemctl enable tor
systemctl enable glider
systemctl enable gobetween
systemctl start tor
systemctl start glider
systemctl start gobetween

rm -rf /opt/src/pkg/mod/cache/