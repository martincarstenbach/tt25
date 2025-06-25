#!/usr/bin/env bash

set -euxo pipefail

#
# update this section as necessary
#
NET_NAME=apex-net
DB_CONTAINER_NAME=db
DB_IMAGE=container-registry.oracle.com/database/free:23.8.0.0-amd64
DB_ADMIN_PWD=changeOnInstall

APEX_DOWNLOAD=https://download.oracle.com/otn_software/apex/apex_24.2_en.zip

ORDS_CONFIG_DIR=ords-config
ORDS_IMAGE=container-registry.oracle.com/database/ords:25.1.1
ORDS_CONTAINER_NAME=ords

#
# download and stage APEX, prepare ORDS
#
[[ ! -f apex.zip ]] && curl -Lo apex.zip ${APEX_DOWNLOAD}
[[ ! -d apex ]] && unzip -q apex.zip
[[ ! -d ${ORDS_CONFIG_DIR} ]] && mkdir ${ORDS_CONFIG_DIR}

#
# pull the necessary images. This makes it _much_ easier to
# deal with the initial database start....
#
podman pull ${DB_IMAGE}
podman pull ${ORDS_IMAGE}

#
# create the network
#
podman network exists ${NET_NAME} || podman network create ${NET_NAME}

#
# start the database. Note that the database's storage is transient,
# create and use a volume if you want to preserve it
#
podman run --detach --rm \
--name ${DB_CONTAINER_NAME} \
--network ${NET_NAME} \
--env ORACLE_PWD="${DB_ADMIN_PWD}" \
--publish 1521:1521 \
${DB_IMAGE}

#
# wait for the database to be accessible, you may have to bump
# the timeout depending on your hardware
#
sleep 10

podman healthcheck run db || {
    echo "ERR: database hasn't started after the timeout, aborting"
    exit 1
}

#
# setup ORDS and APEX (this will take a minute or two)
#
podman run --rm --detach \
--network ${NET_NAME} \
--name ${ORDS_CONTAINER_NAME} \
--volume ${ORDS_CONFIG_DIR}:/etc/ords/config \
--volume ./apex:/opt/oracle/apex:Z \
--publish 8080:8080 \
--env CONN_STRING="${DB_CONTAINER_NAME}/freepdb1" \
--env ORACLE_PWD=${DB_ADMIN_PWD} \
${ORDS_IMAGE}