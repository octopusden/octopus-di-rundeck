ARG RUNDECK_VERSION=4.17.0
FROM rundeck/rundeck:${RUNDECK_VERSION}

USER root

# install Python: required for K8S plugins
RUN apt-get --assume-yes update && \
    apt-get --assume-yes install python3-dev python3-pip && \
    apt-get --assume-yes autoremove && \
    apt-get --assume-yes clean && \
    rm -rf /var/cache/apt/*

# upgrade Python routines and install Python kubernetes client
# NOTE: it is necessary to do this ad system level
# since OKD breaks user-localized installation 
# due to its ows security features paranoia
RUN python3 -m pip install --upgrade pip && \
    python3 -m pip install --upgrade setuptools wheel && \
    python3 -m pip install --upgrade kubernetes 'oc-cdtapi>=3.12.0'

USER rundeck
# install K8S plugins
# install Vault plugin
### NOTE: The exact download URL is unpreditable on GitHub
###       This is the cause to change the exact version manually in the future
RUN cd /home/rundeck/libext && \
    curl --remote-name --request GET --location 'https://github.com/rundeck-plugins/kubernetes/releases/download/2.0.13/kubernetes-2.0.13.zip' && \
    curl --remote-name --request GET --location 'https://github.com/rundeck-plugins/vault-storage/releases/download/1.3.12/vault-storage-1.3.12.jar'

# install our scripts
COPY --chown=rundeck:root bin /home/rundeck/docker-lib
RUN chmod 755 /home/rundeck/docker-lib/*.sh

# it is necessary to make all items in /home/rundeck world-readable and writable
# since OKD changing digital UID for the container user to unpredictable value
# even if it is not root
RUN find /home/rundeck -exec chown rundeck:root \{\} \; -exec chmod a+rw \{\} \; && \
    find /home/rundeck -type d -exec chmod a+x \{\} \;

# redefine base image entrypoint to ours
ENTRYPOINT [ "/bin/bash", "/home/rundeck/docker-lib/entrypoint.sh" ]

# Regardless we are using base image WORKDIR
# some OKD security features wands us to specify the same value here directly
# and this instruction have to be last
WORKDIR /home/rundeck
