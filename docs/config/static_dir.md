# Static Directory

Static frontend files are shipped in `priv/static/` and tracked by version control in this repository. If you want to overwrite or update these without the possibility of merge conflicts, you can write your custom versions to `instance/static/`.

```
config :pleroma, :instance,
  static_dir: "instance/static/",
```

For example, edit `instance/static/instance/panel.html` .

Alternatively, you can overwrite this value in your configuration to use a different static instance directory.

This document is written assuming `instance/static/`.

Or, if you want to manage your custom file in git repository, basically remove the `instance/` entry from `.gitignore`.

## robots.txt

By default, the `robots.txt` that ships in `priv/static/` is permissive. It allows well-behaved search engines to index all of your instance's URIs.

If you want to generate a restrictive `robots.txt`, you can run the following mix task. The generated `robots.txt` will be written in your instance static directory.

```
mix pleroma.robots_txt disallow_all
```

## Thumbnail

Put on `instance/static/instance/thumbnail.jpeg` with your selfie or other neat picture. It will appear in [Pleroma Instances](http://distsn.org/pleroma-instances.html).

## Instance-specific panel

![instance-specific panel demo](/uploads/296b19ec806b130e0b49b16bfe29ce8a/image.png)

Create and Edit your file on `instance/static/instance/panel.html`.

## Background

You can change the background of your Pleroma instance by uploading it to `instance/static/`, and then changing `background` in `config/prod.secret.exs` accordingly.

If you put `instance/static/images/background.jpg`

```
config :pleroma, :frontend_configurations,
  pleroma_fe: %{
    background: "/images/background.jpg"
  }
```

## Logo

![logo modification demo](/uploads/c70b14de60fa74245e7f0dcfa695ebff/image.png)

If you want to give a brand to your instance, You can change the logo of your instance by uploading it to `instance/static/`.

Alternatively, you can specify the path with config.
If you put `instance/static/static/mylogo-file.png`

```
config :pleroma, :frontend_configurations,
  pleroma_fe: %{
   logo: "/static/mylogo-file.png"
  }
```

## Terms of Service

Terms of Service will be shown to all users on the registration page. It's the best place where to write down the rules for your instance. You can modify the rules by changing `instance/static/static/terms-of-service.html`.
