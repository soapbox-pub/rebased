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
