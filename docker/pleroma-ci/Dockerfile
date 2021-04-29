FROM elixir:1.9.4

RUN set -xe \
  && apt-get update \
  && apt-get install -y cmake libimage-exiftool-perl ffmpeg libmagic-dev \
  && mix local.hex --force \
  && mix local.rebar --force \
  && apt-get purge -y --auto-remove \
  && rm -rf /var/lib/apt/lists/*
