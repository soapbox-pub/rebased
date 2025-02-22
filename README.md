Pleroma by mkljczk is a fork of Pleroma I'm developing for personal use.

Added features:

- You can bite users
- `$INSTANCE$host$` gets replaced by domain name of instance viewing your posts
- [Mobilizon-compatible events](https://git.pleroma.social/pleroma/pleroma/-/merge_requests/3955)
- [Machine translation providers (DeepL, LibreTranslate) are supported](https://git.pleroma.social/pleroma/pleroma/-/merge_requests/4102)
- [Post language can be automatically detected (with fastText)](https://git.pleroma.social/pleroma/pleroma/-/merge_requests/4103)
- [A single server can allow users to register accounts with different domains](https://git.pleroma.social/pleroma/pleroma/-/merge_requests/3965)
- [Chats and chat messages get exported in account backups](https://git.pleroma.social/pleroma/pleroma/-/merge_requests/4088)
- [You can pin/unpin chats](https://git.pleroma.social/pleroma/pleroma/-/merge_requests/3637)
- [Partial implementation of Mastodon admin API](https://git.pleroma.social/pleroma/pleroma/-/merge_requests/3671)
- [Moderators can assign users to reports](https://git.pleroma.social/pleroma/pleroma/-/merge_requests/3670)
- [Mastodon-compatible webhooks](https://git.pleroma.social/pleroma/pleroma/-/merge_requests/3683)
- UI is restyled to match pl-fe visuals
- Improved compatibility with akkoma-fe (profiles saving is still missing)

Features ported from other projects:
- [Chat deletion](https://git.pleroma.social/pleroma/pleroma/-/merge_requests/3029)
- [AntiDuplicationPolicy and AntiMentionSpamPolicy MRFs](https://gitlab.com/soapbox-pub/rebased/-/merge_requests/249)
- [Bubble timeline](https://akkoma.dev/AkkomaGang/akkoma/pulls/100)
- [Ability to auto-approve followbacks](https://akkoma.dev/AkkomaGang/akkoma/pulls/674)

There might be more, it's hard to keep track of it. I'm trying to keep the fork as close to upstream and I hope the list will eventually get much shorter.

**DISCLAIMER:**
Although Pleroma by mkljczk *just works* for me, I cannot guarantee that it'll work well for you. There might be bugs I simply don't care about or I might decide to abandon the project one day.

It should be possible to migrate from Pleroma or Rebased to Pleroma by mkljczk without issues. It is recommended to use Pleroma by mkljczk with [`pl-fe`](https://github.com/mkljczk/pl-fe/tree/develop/packages/pl-fe) for full feature compatibility, but pleroma-fe and other frontends work fine too.

---

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
Currently Pleroma is packaged for [YunoHost](https://yunohost.org), [NixOS](https://nixos.org), [Gentoo through GURU](https://gentoo.org/) and [Archlinux through AUR](https://aur.archlinux.org/packages/pleroma). You may find more at <https://repology.org/project/pleroma/versions>.
If you want to package Pleroma for any OS/Distros, we can guide you through the process on our [community channels](#community-channels). If you want to change default options in your Pleroma package, please **discuss it with us first**.

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
