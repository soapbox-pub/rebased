# Static Directory

Static frontend files are shipped in `priv/static/` and tracked by version control in this repository. If you want to overwrite or update these without the possibility of merge conflicts, you can write your custom versions to `instance/static/`.

```
config :pleroma, :instance,
  static_dir: "instance/static/",
```

You can overwrite this value in your configuration to use a different static instance directory.

## robots.txt

By default, the `robots.txt` that ships in `priv/static/` is permissive. It allows well-behaved search engines to index all of your instance's URIs.

If you want to generate a restrictive `robots.txt`, you can run the following mix task. The generated `robots.txt` will be written in your instance static directory.

```
mix pleroma.robots_txt disallow_all
```

# Small customizations

You can directly overwrite files in `priv/static`, but you can also use`instance/static`.

Since `priv` is tracked by git, it is recommended to put panel.html or thumbnail.jpeg and more under the `instance` directory if you do not use your own pleroma git repository.

For example, `instance/static/instance/panel.html`

This is when static_dir is the default.

## Thumbnail

Replace `priv/static/instance/thumbnail.jpeg` with your selfie or other neat picture. It will appear in [Pleroma Instances](http://distsn.org/pleroma-instances.html).

Or put your file on `instance/static/instance/thumbnail.jpeg` when static_dir is default.

## Instance-specific panel

![instance-specific panel demo](/uploads/296b19ec806b130e0b49b16bfe29ce8a/image.png)

To show the instance specific panel, set `show_instance_panel` to `true` in `config/dev.secret.exs`. You can modify its content by editing `priv/static/instance/panel.html`.

Or put your file on `instance/static/instance/panel.html` when static_dir is default.

## Background

You can change the background of your Pleroma instance by uploading it to `priv/static/static`, and then changing `"background"` in `config/dev.secret.exs` accordingly.

Or put your file on `instance/static/static/background.jpg` when static_dir is default.

## Logo

![logo modification demo](/uploads/c70b14de60fa74245e7f0dcfa695ebff/image.png)

If you want to give a brand to your instance, look no further. You can change the logo of your instance by uploading it to `priv/static/static`, and then changing `logo` in `config/dev.secret.exs` accordingly.

Or put your file on `instance/static/static/logo.png` when static_dir is default.

## Terms of Service

Terms of Service will be shown to all users on the registration page. It's the best place where to write down the rules for your instance. You can modify the rules by changing `priv/static/static/terms-of-service.html`.

Or put your file on `instance/static/static/terms-of-service.html` when static_dir is default.
