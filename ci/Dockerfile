FROM elixir:1.12

RUN apt-get update &&\
  apt-get install -y libmagic-dev cmake libimage-exiftool-perl ffmpeg &&\
	mix local.hex --force &&\
	mix local.rebar --force

