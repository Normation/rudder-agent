# rust is the latest debian image with latest rust preinstalled
FROM rust
ARG TYPOS_VERSION=1.36

# Is there a reason to lock a specific version ?
RUN cargo install -f typos-cli --version =$TYPOS_VERSION
RUN apt-get update && apt-get install -y shellcheck pylint asciidoctor
