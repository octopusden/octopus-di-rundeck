ARG RUNDECK_VERSION=4.17.0
FROM rundeck/rundeck:${RUNDECK_VERSION}

USER root

# install Python: required for K8S plugins
# install rundeck cli
RUN curl -s https://packagecloud.io/install/repositories/pagerduty/rundeck/script.deb.sh | os=any dist=any bash
RUN apt-get --assume-yes update && \
    apt-get --assume-yes install python3-dev python3-pip rundeck-cli && \
    apt-get --assume-yes autoremove && \
    apt-get --assume-yes clean && \
    rm -rf /var/cache/apt/*

USER rundeck
# upgrade Python routines and install Python kubernetes client
RUN python3 -m pip install --user --upgrade pip && \
    python3 -m pip install --user --upgrade  setuptools wheel && \
    python3 -m pip install --user --upgrade kubernetes 'oc-cdtapi>=3.12.0'

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

ENTRYPOINT [ "/bin/bash", "/home/rundeck/docker-lib/entrypoint.sh" ]
