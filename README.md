<img src="https://git.pleroma.social/pleroma/pleroma/uploads/8cec84f5a084d887339f57deeb8a293e/pleroma-banner-vector-nopad-notext.svg" width="300px" />

## About 

Pleroma is a microblogging server software that can federate (= exchange messages with) other servers that support ActivityPub. What that means is that you can host a server for yourself or your friends and stay in control of your online identity, but still exchange messages with people on larger servers. Pleroma will federate with all servers that implement ActivityPub, like Friendica, GNU Social, Hubzilla, Mastodon, Misskey, Peertube, and Pixelfed.

Pleroma is written in Elixir and uses PostgresSQL for data storage. It's efficient enough to be ran on low-power devices like Raspberry Pi (though we wouldn't recommend storing the database on the internal SD card ;) but can scale well when ran on more powerful hardware (albeit only single-node for now).

For clients it supports the [Mastodon client API](https://docs.joinmastodon.org/api/guidelines/) with Pleroma extensions (see the API section on <https://docs-develop.pleroma.social>).

- [Client Applications for Pleroma](https://docs-develop.pleroma.social/backend/clients/)

## Installation

### OTP releases (Recommended)
If you are running Linux (glibc or musl) on x86/arm, the recommended way to install Pleroma is by using OTP releases. OTP releases are as close as you can get to binary releases with Erlang/Elixir. The release is self-contained, and provides everything needed to boot it. The installation instructions are available [here](https://docs-develop.pleroma.social/backend/installation/otp_en/).

### From Source
If your platform is not supported, or you just want to be able to edit the source code easily, you may install Pleroma from source.

- [Alpine Linux](https://docs-develop.pleroma.social/backend/installation/alpine_linux_en/)
- [Arch Linux](https://docs-develop.pleroma.social/backend/installation/arch_linux_en/)
- [CentOS 7](https://docs-develop.pleroma.social/backend/installation/centos7_en/)
- [Debian-based](https://docs-develop.pleroma.social/backend/installation/debian_based_en/)
- [Debian-based (jp)](https://docs-develop.pleroma.social/backend/installation/debian_based_jp/)
- [FreeBSD](https://docs-develop.pleroma.social/backend/installation/freebsd_en/)
- [Gentoo Linux](https://docs-develop.pleroma.social/backend/installation/gentoo_en/)
- [NetBSD](https://docs-develop.pleroma.social/backend/installation/netbsd_en/)
- [OpenBSD](https://docs-develop.pleroma.social/backend/installation/openbsd_en/)
- [OpenBSD (fi)](https://docs-develop.pleroma.social/backend/installation/openbsd_fi/)

### OS/Distro packages
Currently Pleroma is packaged for [YunoHost](https://yunohost.org) and [NixOS](https://nixos.org). If you want to package Pleroma for any OS/Distros, we can guide you through the process on our [community channels](#community-channels). If you want to change default options in your Pleroma package, please **discuss it with us first**.

### Docker
While we don’t provide docker files, other people have written very good ones. Take a look at <https://github.com/angristan/docker-pleroma> or <https://glitch.sh/sn0w/pleroma-docker>.

### Raspberry Pi
Community maintained Raspberry Pi image that you can flash and run Pleroma on your Raspberry Pi. Available here <https://github.com/guysoft/PleromaPi>.

### Compilation Troubleshooting
If you ever encounter compilation issues during the updating of Pleroma, you can try these commands and see if they fix things:

- `mix deps.clean --all`
- `mix local.rebar`
- `mix local.hex`
- `rm -r _build`

If you are not developing Pleroma, it is better to use the OTP release, which comes with everything precompiled.

## Documentation
- Latest Released revision: <https://docs.pleroma.social>
- Latest Git revision: <https://docs-develop.pleroma.social>

## Community Channels
* IRC: **#pleroma** and **#pleroma-dev** on libera.chat, webchat is available at <https://irc.pleroma.social>
* Matrix: [#pleroma:libera.chat](https://matrix.to/#/#pleroma:libera.chat) and [#pleroma-dev:libera.chat](https://matrix.to/#/#pleroma-dev:libera.chat)
