# Small customizations
Replace `dev.secret.exs` with `prod.secret.exs` according to your setup.

# Thumbnail

Replace `priv/static/instance/thumbnail.jpeg` with your selfie or other neat picture. It will appear in [Pleroma Instances](http://distsn.org/pleroma-instances.html).

# Instance-specific panel

![instance-specific panel demo](/uploads/296b19ec806b130e0b49b16bfe29ce8a/image.png)

To show the instance specific panel, set `show_instance_panel` to `true` in `config/dev.secret.exs`. You can modify its content by editing `priv/static/instance/panel.html`.

# Background

You can change the background of your Pleroma instance by uploading it to `priv/static/static`, and then changing `"background"` in `config/dev.secret.exs` accordingly.

# Logo

![logo modification demo](/uploads/c70b14de60fa74245e7f0dcfa695ebff/image.png)

If you want to give a brand to your instance, look no further. You can change the logo of your instance by uploading it to `priv/static/static`, and then changing `logo` in `config/dev.secret.exs` accordingly.

# Theme

All users of your instance will be able to change the theme they use by going to the settings (the cog in the top-right hand corner). However, if you wish to change the default theme, you can do so by editing `theme` in `config/dev.secret.exs` accordingly.

# Terms of Service

Terms of Service will be shown to all users on the registration page. It's the best place where to write down the rules for your instance. You can modify the rules by changing `priv/static/static/terms-of-service.html`.

# Message Visibility

To enable message visibility options when posting like in the Mastodon frontend, set
`scope_options_enabled` to `true` in `config/dev.secret.exs`.
