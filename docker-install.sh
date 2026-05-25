#!/usr/bin/env bash

# Copyright (c) 2021-2026 tteck
# Author: tteck (tteckster)
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://www.docker.com/

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

DOCKER_LATEST_VERSION=$(get_latest_github_release "moby/moby")
PORTAINER_LATEST_VERSION=$(get_latest_github_release "portainer/portainer")
PORTAINER_AGENT_LATEST_VERSION=$(get_latest_github_release "portainer/agent")

msg_info "Installing Docker $DOCKER_LATEST_VERSION (with Compose, Buildx)"
DOCKER_CONFIG_PATH='/etc/docker/daemon.json'
mkdir -p $(dirname $DOCKER_CONFIG_PATH)
echo -e '{\n  "log-driver": "journald"\n}' >/etc/docker/daemon.json
$STD sh <(curl -fsSL https://get.docker.com)
msg_ok "Installed Docker $DOCKER_LATEST_VERSION"



socket="tcp://0.0.0.0:2375"

if [[ -n "$socket" ]]; then
  msg_info "Enabling Docker TCP socket on $socket"
  $STD apt-get install -y jq

  tmpfile=$(mktemp)
  jq --arg sock "$socket" '. + { "hosts": ["unix:///var/run/docker.sock", $sock] }' /etc/docker/daemon.json >"$tmpfile" && mv "$tmpfile" /etc/docker/daemon.json

  mkdir -p /etc/systemd/system/docker.service.d
  cat <<EOF >/etc/systemd/system/docker.service.d/override.conf
[Service]
ExecStart=
ExecStart=/usr/bin/dockerd
EOF

  $STD systemctl daemon-reexec
  $STD systemctl daemon-reload

  if systemctl restart docker; then
    msg_ok "Docker TCP socket available on $socket"
  else
    msg_error "Docker failed to restart. Check journalctl -xeu docker.service"
    exit 150
  fi
fi

motd_ssh
customize
cleanup_lxc
