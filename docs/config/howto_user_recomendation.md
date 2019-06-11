# How to activate user recommendation (Who to follow panel)
![who-to-follow-panel-small](/uploads/9de1b1300436c32461d272945f1bc23e/who-to-follow-panel-small.png)

To show the *who to follow* panel, edit `config/prod.secret.exs` in the Pleroma backend. Following code activates the *who to follow* panel:

```elixir
config :pleroma, :suggestions,
  enabled: true,
  third_party_engine:
    "http://vinayaka.distsn.org/cgi-bin/vinayaka-user-match-suggestions-api.cgi?{{host}}+{{user}}",
  timeout: 300_000,
  limit: 40,
  web: "https://vinayaka.distsn.org"

```

`config/config.exs` already includes this code, but `enabled:` is `false`.

`/api/v1/suggestions` is also provided when *who to follow* panel is enabled.

For advanced customization, following code shows the newcomers of the fediverse at the *who to follow* panel:

```elixir
config :pleroma, :suggestions,
  enabled: true,
  third_party_engine:
    "http://vinayaka.distsn.org/cgi-bin/vinayaka-user-new-suggestions-api.cgi?{{host}}+{{user}}",
  timeout: 60_000,
  limit: 40,
  web: "https://vinayaka.distsn.org/user-new.html"
```
