# OpenLiberty base image
FROM 126924000548.dkr.ecr.us-east-1.amazonaws.com/liberty/liberty-base:latest

LABEL maintainer="pixiecloud Middleware Team"

USER root

# Copy s2i scripts
COPY --chown=1001:0 s2i/bin/ /usr/local/s2i/
COPY --chown=1001:0 root/usr/bin /usr/bin

# Install required packages
RUN microdnf install -y shadow-utils && \
    microdnf clean all

# Create necessary directories
RUN chmod -R g+rw /logs && \
    mkdir -p $HOME && \
    chmod -R g+rw $HOME && \
    mkdir -p /opt/ibm/wlp/output/defaultServer/workarea && \
    chown -R 1001:0 /opt/ibm/wlp/output/defaultServer/workarea && \
    chmod -R g+rw /opt/ibm/wlp/output/defaultServer/workarea && \
    chown -R 1001:0 /opt/ibm/wlp/usr/shared/resources && \
    chmod -R g+rw /opt/ibm/wlp/usr/shared/resources && \
    chmod g+u /etc/passwd && \
    chmod -R 777 $LIBERTY_JDK_PATH

# Set base image type
RUN if [ "$LIBERTY_IMAGE_TYPE" = "full" ]; then \
        chown -R 1001:0 /etc/ssh/ssh_config && \
        chmod g+u /etc/ssh/ssh_config; \
    fi

# Remove entitlements
RUN rm -rf /etc/pki/entitlement && \
    rm -rf /etc/rhsm && \
    rm -rf /etc/pki-entitlement && \
    rm -rf ./rhsm-conf && \
    rm -rf ./rhsm-ca

WORKDIR $HOME

EXPOSE $WLP_DEBUG_ADDRESS

USER 1001

ENTRYPOINT ["container-entrypoint"]

CMD ["base-usage"]
