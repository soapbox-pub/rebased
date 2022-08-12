FROM ubuntu:22.04 as build

ENV MIX_ENV=prod \
    OAUTH_CONSUMER_STRATEGIES="twitter facebook google microsoft slack github keycloak:ueberauth_keycloak_strategy"

WORKDIR /src

RUN apt-get update &&\
    apt-get install -y git elixir erlang-dev erlang-nox build-essential cmake libssl-dev libmagic-dev automake autoconf libncurses5-dev &&\
    mix local.hex --force &&\
    mix local.rebar --force

COPY . /src

RUN cd /src &&\
    mix deps.get --only prod &&\
    mkdir release &&\
    mix release --path release

FROM ubuntu:22.04

ARG BUILD_DATE
ARG VCS_REF

ARG DEBIAN_FRONTEND="noninteractive"
ENV TZ="Etc/UTC"

LABEL maintainer="hello@soapbox.pub" \
    org.opencontainers.image.title="soapbox-be" \
    org.opencontainers.image.description="Soapbox BE for Docker" \
    org.opencontainers.image.authors="hello@soapbox.pub" \
    org.opencontainers.image.vendor="soapbox.pub" \
    org.opencontainers.image.documentation="https://gitlab.com/soapbox-pub/soapbox-be" \
    org.opencontainers.image.licenses="AGPL-3.0" \
    org.opencontainers.image.url="https://soapbox.pub" \
    org.opencontainers.image.revision=$VCS_REF \
    org.opencontainers.image.created=$BUILD_DATE

ARG HOME=/opt/pleroma
ARG DATA=/var/lib/pleroma

RUN apt-get update &&\
    apt-get install -y --no-install-recommends imagemagick libmagic-dev ffmpeg libimage-exiftool-perl libncurses5 postgresql-client &&\
    adduser --system --shell /bin/false --home ${HOME} pleroma &&\
    mkdir -p ${DATA}/uploads &&\
    mkdir -p ${DATA}/static &&\
    chown -R pleroma ${DATA} &&\
    mkdir -p /etc/pleroma &&\
    chown -R pleroma /etc/pleroma

USER pleroma

COPY --from=build --chown=pleroma:0 /src/release ${HOME}

COPY ./config/docker.exs /etc/pleroma/config.exs
COPY ./docker-entrypoint.sh ${HOME}

ENTRYPOINT ["/opt/pleroma/docker-entrypoint.sh"]
