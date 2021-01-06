# Static Directory

Static frontend files are shipped with pleroma. If you want to overwrite or update these without problems during upgrades, you can write your custom versions to the static directory.

You can find the location of the static directory in the [configuration](../cheatsheet/#instance).

=== "OTP"

    ```elixir
    config :pleroma, :instance,
      static_dir: "/var/lib/pleroma/static/"
    ```

=== "From Source"

    ```elixir
    config :pleroma, :instance,
    static_dir: "instance/static/"
    ```

Alternatively, you can overwrite this value in your configuration to use a different static instance directory.

This document is written using `$static_dir` as the value of the `config :pleroma, :instance, static_dir` setting.

If you use a From Source installation and want to manage your custom files in the git repository, you can remove the `instance/` entry from `.gitignore`.

## robots.txt

There's a mix tasks to [generate a new robot.txt](../../administration/CLI_tasks/robots_txt/).

For more complex things, you can write your own robots.txt to `$static_dir/robots.txt`.

E.g. if you want to block all crawlers except for [fediverse.network](https://fediverse.network/about) you can use

```
User-Agent: *
Disallow: /

User-Agent: crawler-us-il-1.fediverse.network
Allow: /

User-Agent: makhnovtchina.random.sh
Allow: /
```

## Thumbnail

Add `$static_dir/instance/thumbnail.jpeg` with your selfie or other neat picture. It will be available on `http://your-domain.tld/instance/thumbnail.jpeg` and can be used by external applications.

## Instance-specific panel

Create and Edit your file at `$static_dir/instance/panel.html`.

## Background

You can change the background of your Pleroma instance by uploading it to `$static_dir/`, and then changing `background` in [your configuration](../cheatsheet/#frontend_configurations) accordingly.

E.g. if you put `$static_dir/images/background.jpg`

```
config :pleroma, :frontend_configurations,
  pleroma_fe: %{
    background: "/images/background.jpg"
  }
```

## Logo

!!! important
    Note the extra `static` folder for the default logo.png location

If you want to give a brand to your instance, You can change the logo of your instance by uploading it to the static directory `$static_dir/static/logo.png`.

Alternatively, you can specify the path to your logo in [your configuration](../cheatsheet/#frontend_configurations).

E.g. if you put `$static_dir/static/mylogo-file.png`

```
config :pleroma, :frontend_configurations,
  pleroma_fe: %{
   logo: "/static/mylogo-file.png"
  }
```

## Terms of Service

!!! important
    Note the extra `static` folder for the terms-of-service.html

Terms of Service will be shown to all users on the registration page. It's the best place where to write down the rules for your instance. You can modify the rules by adding and changing `$static_dir/static/terms-of-service.html`.

 	
## Styling rendered pages

To overwrite the CSS stylesheet of the OAuth form and other static pages, you can upload your own CSS file to `instance/static/static.css`. This will completely replace the CSS used by those pages, so it might be a good idea to copy the one from `priv/static/instance/static.css` and make your changes.
