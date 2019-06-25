# Switching a from-source install to OTP releases
## Why would one want to switch?
Benefits of OTP releases over from-source installs include:
* **Less space used.** OTP releases come without source code, build tools, have docs and debug symbols stripped from the compiled bytecode and do not cointain tests and docs.
* **Minimal system dependencies.** Excluding the database and reverse proxy, all you need to download and run a release is `curl`, `unzip` and `ncurses`. Because Erlang runtime and Elixir are shipped with Pleroma, one can use the latest BEAM optimizations and Pleroma features, without having to worry about outdated system repos or a missing `erlang-*` package.
* **Potentially less bugs and better performance.** This extends on the previous point, because we have control over exactly what gets shipped, we can tweak the VM arguments and forget about weird bugs due to Erlang/Elixir version mismatches.
* **Faster and less bug-prone mix tasks.** On a from-source install one has to wait untill a new Pleroma node is started for each mix task and they execute outside of the instance context (for example if you deleted a user via a mix task, the instance will have no knowledge of that and continue to display status count and follows before the cache expires). Mix tasks in OTP releases are executed by calling into a running instance via RPC, which solves both of these problems.

### Sounds great, how do I switch?
Currently we support Linux machines with GNU (e.g. Debian, Ubuntu) or musl (e.g. Alpine) libc and `x86_64`, `aarch64` or `armv7l` CPUs. If you are unsure you can check the [Detecting flavour](otp_en.html#detecting-flavour) section in OTP install guide. If your platform is supported, proceed with the guide, if not check the [My platform is not supported](#my-platform-is-not-supported) section.
### I don't think it is worth the effort, can I stay on a from-source install?
Yes, currently there are no plans to deprecate them.
### My platform is not supported
If you believe your platform is a popular choice for running Pleroma instances, or has the potential to become one you can [file an issue on our Gitlab](https://git.pleroma.social/pleroma/pleroma/issues/new). If not, guides on how to build and update releases by yourself will be available soon.
## Moving uploads/instance static directory
## Moving emoji
## Moving the config
## Installing the release
