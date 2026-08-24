ARG SPLUNK_IMAGE=splunk/splunk:10.4.1
FROM ${SPLUNK_IMAGE}

# Prefixes the entrypoint's log lines.
ARG LAB_NAME=splunk-lab

USER root

# Staged under /lab, not written straight into /opt/splunk/etc: the base image
# declares that path a Docker VOLUME, so content placed there in an image layer
# is at the mercy of first-boot provisioning. The entrypoint installs it.
COPY conf/ /lab/conf/
COPY logs/ /lab/logs/
COPY entrypoint.sh /sbin/lab-entrypoint.sh

# splunkd runs as `splunk`, and a monitor input only reads what that user can
# read -- an unreadable log directory yields an empty index and no error.
RUN chmod 0755 /sbin/lab-entrypoint.sh \
    && chown -R splunk:splunk /lab \
    && find /lab -type d -exec chmod 0755 {} + \
    && find /lab -type f -exec chmod 0644 {} +

ENV LAB_NAME="${LAB_NAME}"

USER ansible
ENTRYPOINT ["/sbin/lab-entrypoint.sh"]
CMD ["start-service"]
