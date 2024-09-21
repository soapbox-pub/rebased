# https://hub.docker.com/r/hexpm/elixir/tags
ARG ELIXIR_IMG=hexpm/elixir
ARG ELIXIR_VER=1.14.5
ARG ERLANG_VER=25.3.2.14
ARG ALPINE_VER=3.17.9

FROM ${ELIXIR_IMG}:${ELIXIR_VER}-erlang-${ERLANG_VER}-alpine-${ALPINE_VER} as build

COPY . .

ENV MIX_ENV=prod
ENV VIX_COMPILATION_MODE=PLATFORM_PROVIDED_LIBVIPS

RUN apk add git gcc g++ musl-dev make cmake file-dev vips-dev &&\
	echo "import Config" > config/prod.secret.exs &&\
	mix local.hex --force &&\
	mix local.rebar --force &&\
	mix deps.get --only prod &&\
	mkdir release &&\
	mix release --path release

FROM alpine:${ALPINE_VER}

ARG BUILD_DATE
ARG VCS_REF

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

RUN apk update &&\
	apk add exiftool ffmpeg vips libmagic ncurses postgresql-client &&\
	adduser --system --shell /bin/false --home ${HOME} pleroma &&\
	mkdir -p ${DATA}/uploads &&\
	mkdir -p ${DATA}/static &&\
	chown -R pleroma ${DATA} &&\
	mkdir -p /etc/pleroma &&\
	chown -R pleroma /etc/pleroma

USER pleroma

COPY --from=build --chown=pleroma:0 /release ${HOME}

COPY --chown=pleroma --chmod=640 ./config/docker.exs /etc/pleroma/config.exs
COPY ./docker-entrypoint.sh ${HOME}

EXPOSE 4000

ENTRYPOINT ["/opt/pleroma/docker-entrypoint.sh"]
