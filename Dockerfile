FROM rinpatch/elixir:1.9.0-rc.0-alpine as build

COPY . .

ENV MIX_ENV prod

RUN apk add git gcc g++ musl-dev make &&\
	echo "import Mix.Config" > config/prod.secret.exs &&\
	mix local.hex --force &&\
	mix local.rebar --force

RUN mix deps.get --only prod &&\
	mkdir release &&\
	mix release --path release

FROM alpine:latest

RUN echo "http://nl.alpinelinux.org/alpine/latest-stable/community" >> /etc/apk/repositories &&\
	apk update &&\
	apk add ncurses postgresql-client

RUN adduser --system --shell /bin/false --home /opt/pleroma pleroma &&\
	mkdir -p /var/lib/pleroma/uploads &&\
	chown -R pleroma /var/lib/pleroma &&\
	mkdir -p /var/lib/pleroma/static &&\
	chown -R pleroma /var/lib/pleroma &&\
	mkdir -p /etc/pleroma &&\
	chown -R pleroma /etc/pleroma

USER pleroma

COPY --from=build --chown=pleroma:0 /release/ /opt/pleroma/
