# https://hub.docker.com/r/hexpm/elixir/tags
FROM hexpm/elixir:1.17.3-erlang-27.1.3-alpine-3.21.3 AS build

ENV MIX_ENV=prod
ENV ERL_EPMD_ADDRESS=127.0.0.1
ENV VIX_COMPILATION_MODE=PLATFORM_PROVIDED_LIBVIPS

ARG HOME=/opt/pleroma

LABEL org.opencontainers.image.title="pleroma" \
    org.opencontainers.image.description="pleroma for Docker" \
    org.opencontainers.image.vendor="pleroma.dev" \
    org.opencontainers.image.documentation="https://docs.pleroma.dev/stable/" \
    org.opencontainers.image.licenses="AGPL-3.0" \
    org.opencontainers.image.url="https://pleroma.dev" \
    org.opencontainers.image.revision=$VCS_REF \
    org.opencontainers.image.created=$BUILD_DATE

RUN apk add git gcc g++ musl-dev make cmake file-dev curl exiftool ffmpeg libmagic ncurses postgresql-client vips-dev fasttext

EXPOSE 4000

ARG UID=1000
ARG GID=1000
ARG UNAME=pleroma

RUN addgroup -g $GID $UNAME
RUN adduser -u $UID -G $UNAME -D -h $HOME $UNAME

WORKDIR /opt/pleroma

USER $UNAME
RUN mix local.hex --force &&\
    mix local.rebar --force

RUN mkdir -p fasttext &&\
    curl -L https://dl.fbaipublicfiles.com/fasttext/supervised-models/lid.176.ftz -o fasttext/lid.176.ftz &&\
    chmod 0644 fasttext/lid.176.ftz

CMD ["/opt/pleroma/docker-entrypoint.sh"]
