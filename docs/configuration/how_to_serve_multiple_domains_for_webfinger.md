# How to serve multiple domains for Pleroma user identifiers

It is possible to use multiple domains for WebFinger identifiers. If configured, users can select from the available domains during registration. Domains can be set by instance administrator and can be marked as either public (everyone can choose it) or private (only available when admin creates a user)

## Configuring

### Configuring Pleroma

To enable using multiple domains, append the following to your `prod.secret.exs` or `dev.secret.exs`:
```elixir
config :pleroma, :instance, :multitenancy, enabled: true
```

Creating, updating and deleting domains is available from the admin API.

### Configuring WebFinger domains

If you recall how webfinger queries work, the first step is to query `https://example.org/.well-known/host-meta`, which will contain an URL template.

Therefore, the easiest way to configure the additional domains is to redirect `/.well-known/host-meta` to the domain used by Pleroma.

With nginx, it would be as simple as adding:

```nginx
location = /.well-known/host-meta {
       return 301 https://pleroma.example.org$request_uri;
}
```

in the additional domain's server block.
