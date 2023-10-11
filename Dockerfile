ARG RUNDECK_VERSION=4.17.0
FROM rundeck/rundeck:${RUNDECK_VERSION}

USER root

# install rundeck cli
RUN curl -s https://packagecloud.io/install/repositories/pagerduty/rundeck/script.deb.sh | os=any dist=any bash
RUN apt-get update && apt-get install --assume-yes rundeck-cli && apt-get autoremove --assume-yes && apt-get --assume-yes clean

# install our scripts
COPY --chown=rundeck:root bin /home/rundeck/docker-lib
RUN chmod 755 /home/rundeck/docker-lib/*.sh && \
    mv /home/rundeck /local/rundeck && \
    mkdir -p /home/rundeck && \
    chown -R rundeck:root /home/rundeck

USER rundeck
ENTRYPOINT [ "/bin/bash", "/local/rundeck/docker-lib/entrypoint.sh" ]
