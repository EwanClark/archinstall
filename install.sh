#! /bin/bash
set -Eeuo pipefail

curl -L https://github.com/EwanClark/archinstall/archive/refs/heads/main.zip -o archinstall.zip
bsdtar -xf archinstall.zip
cd archinstall-main
chmod +x init.sh
./init.sh