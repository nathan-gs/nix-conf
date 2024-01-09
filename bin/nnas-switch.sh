#!/usr/bin/env bash

bold=$(tput bold)
normal=$(tput sgr0)

echo "${bold}Checking diskspace${normal}"
ssh nnas.wg "df -h /"

echo "${bold}Updating git repo's${normal}"
ssh nnas.wg "cd /etc/nixos/secrets ; git pull"
ssh nnas.wg "cd /etc/nixos/nix-conf ; git pull"

echo "${bold}Switching to config${normal}"
ssh nnas.wg "cd /etc/nixos/nix-conf ; sudo ./switch.sh"