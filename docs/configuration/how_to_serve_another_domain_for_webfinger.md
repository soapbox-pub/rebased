# How to use a different domain name for Pleroma and the users it serves

Pleroma users are primarily identified by a `user@example.org` handle, and you might want this identifier to be the same as your email or jabber account, for instance.
However, in this case, you are almost certainly serving some web content on `https://example.org` already, and you might want to use another domain (say `pleroma.example.org`) for Pleroma itself.

Pleroma supports that, but it might be tricky to set up, and any error might prevent you from federating with other instances.

*If you are already running Pleroma on `example.org`, it is no longer possible to move it to `pleroma.example.org`.*

## Account identifiers

It is important to understand that for federation purposes, a user in Pleroma has two unique identifiers associated:

- A webfinger `acct:` URI, used for discovery and as a verifiable global name for the user across Pleroma instances. In our example, our account's acct: URI is `acct:user@example.org`
- An author/actor URI, used in every other aspect of federation. This is the way in which users are identified in ActivityPub, the underlying protocol used for federation with other Pleroma instances.
In our case, it is `https://pleroma.example.org/users/user`.

Both account identifiers are unique and required for Pleroma. An important risk if you set up your Pleroma instance incorrectly is to create two users (with different acct: URIs) with conflicting author/actor URIs.

## WebFinger

As said earlier, each Pleroma user has an `acct`: URI, which is used for discovery and authentication. When you add @user@example.org, a webfinger query is performed. This is done in two steps:

1. Querying `https://example.org/.well-known/host-meta` (where the domain of the URL matches the domain part of the `acct`: URI) to get information on how to perform the query.
This file will indeed contain a URL template of the form `https://example.org/.well-known/webfinger?resource={uri}` that will be used in the second step.
2. Fill the returned template with the `acct`: URI to be queried and perform the query: `https://example.org/.well-known/webfinger?resource=acct:user@example.org`

## Configuring your Pleroma instance

**_DO NOT ATTEMPT TO CONFIGURE YOUR INSTANCE THIS WAY IF YOU DID NOT UNDERSTAND THE ABOVE_**

### Configuring Pleroma

Pleroma has a two configuration settings to enable using different domains for your users and Pleroma itself. `host` in `Pleroma.Web.Endpoint` and `domain` in `Pleroma.Web.WebFinger`. When the latter is not set, it defaults to the value of `host`.

*Be extra careful when configuring your Pleroma instance, as changing `host` may cause remote instances to register different accounts with the same author/actor URI, which will result in federation issues!*

```elixir
config :pleroma, Pleroma.Web.Endpoint,
  url: [host: "pleroma.example.org"]

config :pleroma, Pleroma.Web.WebFinger, domain: "example.org"
```

- `domain` - is the domain for which your Pleroma instance has authority, it's the domain used in `acct:` URI. In our example, `domain` would be set to `example.org`. This is used in WebFinger account ids, which are the canonical account identifier in some other fediverse software like Mastodon. **If you change `domain`, the accounts on your server will be shown as different accounts in those software**.
- `host` - is the domain used for any URL generated for your instance, including the author/actor URL's. In our case, that would be `pleroma.example.org`. This is used in AP ids, which are the canonical account identifier in Pleroma and some other fediverse software. **You should not change this after you have set up the instance**.

### Configuring WebFinger domain

Now, you have Pleroma running at `https://pleroma.example.org` as well as a website at `https://example.org`. If you recall how webfinger queries work, the first step is to query `https://example.org/.well-known/host-meta`, which will contain an URL template.

Therefore, the easiest way to configure `example.org` is to redirect `/.well-known/host-meta` to `pleroma.example.org`.

With nginx, it would be as simple as adding:

```nginx
location = /.well-known/host-meta {
       return 301 https://pleroma.example.org$request_uri;
}
```

in example.org's server block.
