FROM ubuntu:22.04 as build

ENV MIX_ENV=prod
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

LABEL maintainer="ops@pleroma.social" \
    org.opencontainers.image.title="pleroma" \
    org.opencontainers.image.description="Pleroma for Docker" \
    org.opencontainers.image.authors="ops@pleroma.social" \
    org.opencontainers.image.vendor="pleroma.social" \
    org.opencontainers.image.documentation="https://git.pleroma.social/pleroma/pleroma" \
    org.opencontainers.image.licenses="AGPL-3.0" \
    org.opencontainers.image.url="https://pleroma.social" \
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

EXPOSE 4000

ENTRYPOINT ["/opt/pleroma/docker-entrypoint.sh"]
