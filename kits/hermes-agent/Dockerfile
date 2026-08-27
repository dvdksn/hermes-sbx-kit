# syntax=docker/dockerfile:1

ARG BASE_IMAGE=docker/sandbox-templates:shell-docker
FROM ${BASE_IMAGE}

ARG BASE_IMAGE

USER agent
ENV HERMES_HOME=/home/agent/.hermes
ENV HERMES_INSTALL_DIR=/home/agent/.local/share/hermes-agent

# Install Hermes at image-build time. Provider configuration is intentionally
# deferred to runtime, where the sandbox proxy supplies host-managed secrets.
RUN curl -fsSL https://hermes-agent.nousresearch.com/install.sh \
    | bash -s -- --skip-setup --non-interactive

USER root
COPY --chmod=0755 start.sh /usr/local/bin/hermes-start
LABEL com.docker.sandboxes.start-docker="true"
LABEL com.docker.sandboxes.flavor="hermes-agent"
LABEL com.docker.sandboxes.base="${BASE_IMAGE}"

USER agent
CMD ["/usr/local/bin/hermes-start"]
