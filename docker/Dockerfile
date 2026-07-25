FROM ubuntu:24.04

# Imaget inneholder verktøyene og menyen — ikke repo, samtaler eller nøkler.
# Alt det monteres inn ved kjøring (se compose.yml).
ARG CLAUDE_VERSION=stable

RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        fzf whiptail jq git curl ca-certificates ripgrep less \
    && rm -rf /var/lib/apt/lists/*

# Native installer, ikke npm — den tar stable|latest|VERSION som argument,
# så et pinnet bygg er én --build-arg.
RUN curl -fsSL https://claude.ai/install.sh | bash -s "$CLAUDE_VERSION" \
    && ln -sf /root/.local/bin/claude /usr/local/bin/claude \
    && claude --version

COPY claude-meny.sh /opt/claude-meny/claude-meny.sh
RUN printf '[ -f /opt/claude-meny/claude-meny.sh ] && source /opt/claude-meny/claude-meny.sh\n' \
        >> /etc/bash.bashrc

# Samme stier som på host — se docs/DOCKER.md om hvorfor det er et krav
ENV CLAUDE_CONFIG_DIR=/root/Claude/.claude
WORKDIR /root/workspace

# «docker compose run --rm meny» går rett i menyen; «... run meny bash» gir shell
CMD ["bash", "-lc", "claude -meny"]
