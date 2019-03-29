# General tips for customizing Pleroma FE
There are some configuration scripts for Pleroma BE and FE:

1. `config/prod.secret.exs`
1. `config/config.exs`
1. `priv/static/static/config.json`

The `prod.secret.exs` affects first. `config.exs` is for fallback or default. `config.json` is for GNU-social-BE-Pleroma-FE instances.

Usually all you have to do is:

1. Copy the section in the `config/config.exs` which you want to activate.
1. Paste into `config/prod.secret.exs`.
1. Edit `config/prod.secret.exs`.
1. Restart the Pleroma daemon.

`prod.secret.exs` is for the `MIX_ENV=prod` environment. `dev.secret.exs` is for the `MIX_ENV=dev` environment respectively.
