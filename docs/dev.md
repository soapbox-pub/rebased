This document contains notes and guidelines for Pleroma developers.

# Authentication & Authorization

## OAuth token-based authentication & authorization

* Pleroma supports hierarchical OAuth scopes, just like Mastodon but with added granularity of admin scopes.
  For a reference, see [Mastodon OAuth scopes](https://docs.joinmastodon.org/api/oauth-scopes/).

* It is important to either define OAuth scope restrictions or explicitly mark OAuth scope check as skipped, for every 
    controller action. To define scopes, call `plug(Pleroma.Plugs.OAuthScopesPlug, %{scopes: [...]})`. To explicitly set 
    OAuth scopes check skipped, call `plug(:skip_plug, Pleroma.Plugs.OAuthScopesPlug <when ...>)`.

* In controllers, `use Pleroma.Web, :controller` will result in `action/2` (see `Pleroma.Web.controller/0` for definition)
    be called prior to actual controller action, and it'll perform security / privacy checks before passing control to
    actual controller action. For routes with `:authenticated_api` pipeline, authentication & authorization are expected,
    thus `OAuthScopesPlug` will be run unless explicitly skipped (also `EnsureAuthenticatedPlug` will be executed
    immediately before action even if there was an early run to give an early error, since `OAuthScopesPlug` supports
    `:proceed_unauthenticated` option, and other plugs may support similar options as well). For `:api` pipeline routes,
    `EnsurePublicOrAuthenticatedPlug` will be called to ensure that the instance is not private or user is authenticated
    (unless explicitly skipped). Such automated checks help to prevent human errors and result in higher security / privacy
    for users.

## [HTTP Basic Authentication](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Authorization)

* With HTTP Basic Auth, OAuth scopes check is _not_ performed for any action (since password is provided during the auth,
    requester is able to obtain a token with full permissions anyways). `Pleroma.Plugs.AuthenticationPlug` and
    `Pleroma.Plugs.LegacyAuthenticationPlug` both call `Pleroma.Plugs.OAuthScopesPlug.skip_plug(conn)` when password
    is provided.

## Auth-related configuration, OAuth consumer mode etc.

See `Authentication` section of [`docs/configuration/cheatsheet.md`](docs/configuration/cheatsheet.md#authentication).
