FROM elixir:1.13.4-otp-24

# Single RUN statement, otherwise intermediate images are created
# https://docs.docker.com/develop/develop-images/dockerfile_best-practices/#run
RUN apt-get update &&\
	apt-get install -y libmagic-dev cmake libimage-exiftool-perl ffmpeg &&\
	mix local.hex --force &&\
	mix local.rebar --force
