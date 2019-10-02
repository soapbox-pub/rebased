# Small customizations

See also static_dir.md for visual settings.

## Theme

All users of your instance will be able to change the theme they use by going to the settings (the cog in the top-right hand corner). However, if you wish to change the default theme, you can do so by editing `theme` in `config/dev.secret.exs` accordingly.

## Message Visibility

To enable message visibility options when posting like in the Mastodon frontend, set
`scope_options_enabled` to `true` in `config/dev.secret.exs`.
