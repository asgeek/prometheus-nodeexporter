#!/bin/bash

set -e 

if [[ -f linux-exporter.env ]]; then
    source linux-exporter.env
fi

if [[ -f linux-exporter-defaults ]]; then
    source linux-exporter-defaults
fi

log () {
    echo "INFO: $*"
}

err () {
    echo "ERROR: $*"
}

log "Node exporter setup script"

cleanup () {
    log "Clean up the server"
    
    require_params USERNAME USER_HOME NODE_EXPORTER_SERVICE NODE_EXPORTER_BIN

    # delete service
    if [[ -f /etc/systemd/system/$NODE_EXPORTER_SERVICE ]]; then
        systemctl stop $NODE_EXPORTER_SERVICE
        systemctl disable $NODE_EXPORTER_SERVICE
        log "Delete $NODE_EXPORTER_SERVICE"
        rm /etc/systemd/system/$NODE_EXPORTER_SERVICE
        systemctl daemon-reload
    fi

    if id -u $USERNAME > /dev/null 2>&1; then
        log "Delete user $USERNAME"
        userdel -r $USERNAME
        if [[ -d "$USER_HOME" ]]; then
            log "Delete home dir $USER_HOME"
            rm -r $USER_HOME
        fi
    fi        

    # delete node_exporter binary
    if [[ -e $NODE_EXPORTER_BIN ]]; then
        log "Delete node_exporter binary"
        rm $NODE_EXPORTER_BIN
    fi    
}

error () {
    trap : SIGTERM ERR
    cleanup
    err "An error occured on line number $2"
    err "Node exporter setup failed with error code: $1"
    exit $1
}

require_params() {
    for param in $@ ; do
        if [[ -z "${!param}" ]]; then
            err "ERROR: $param is unset!"
            exit 1
        fi
    done >&2
}

trap 'error $? $LINENO' SIGTERM ERR

require_params GROUP USERNAME USER_HOME VERSION

if systemctl is-active --quiet $NODE_EXPORTER_SERVICE; then
    log "Node exporter is already running"
    cleanup
fi

if ! id -u $USERNAME > /dev/null 2>&1; then
    log "Create user group $GROUP and $USERNAME"
    # Create new group ex: mon-agent
    groupadd $GROUP 

    # Create new user ex: mon-agent
    useradd -m -g $GROUP $USERNAME 
else
    log "User $USERNAME already exists"
fi

# Unarchive node exporter
if [[ -f node_exporter-$VERSION.linux-amd64.tar.gz ]]; then
    log "node_exporter-$VERSION.linux-amd64.tar.gz exists"
    if [[ ! -f $USER_HOME/node_exporter-$VERSION.linux-amd64 ]]; then
        tar -C $USER_HOME -xvzf node_exporter-$VERSION.linux-amd64.tar.gz 
    fi
fi

cd $USER_HOME

# create symlink “/usr/bin/node_exporter ” to node exporter home/mon-agents/ node_exporter-{{ node_exporter_version }}.linux-amd64
if [[ -d node_exporter-$VERSION.linux-amd64 ]]; then
    log "Create symlink to node_exporter binary"
    ln -s $USER_HOME/node_exporter-$VERSION.linux-amd64 $NODE_EXPORTER_BIN
else
    err "Failed to unarchive node exporter"
    false
fi

# grant access to node exporter executable to mon-agent user
log "Grant access to node exporter executable to $USERNAME user"
chown $USERNAME:$GROUP $NODE_EXPORTER_BIN

# add node exporter startup script into systemd 
cd /etc/systemd/system

cat << EOF > node_exporter.service
[Unit]
Description=Node Exporter $VERSION
Version=$VERSION
After=network-online.target

[Service]
User=$USERNAME
Group=$GROUP
Type=simple
ExecStart=/usr/local/bin/node_exporter/node_exporter

[Install]
WantedBy=multi-user.target
EOF

# configure systemd to use service 
log "Start $NODE_EXPORTER_SERVICE"
systemctl daemon-reload
systemctl start $NODE_EXPORTER_SERVICE
systemctl enable $NODE_EXPORTER_SERVICE

# test service
log "Testing node_exporter service"

if curl --write-out %{http_code} --silent --output /dev/null http://localhost:9100/metrics > /dev/null 2>&1; then 
    log "node_exporter service is now availabe at http://localhost:9100"
else
    err "node_exporter is not running!"
    false
fi