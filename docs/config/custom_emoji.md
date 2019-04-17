# Custom Emoji

To add custom emoji:
* Add the image file(s) to `priv/static/emoji/custom`
* In case of conflicts: add the desired shortcode with the path to `config/custom_emoji.txt`, comma-separated and one per line
* Force recompilation (``mix clean && mix compile``)

Example:

image files (in `/priv/static/emoji/custom`): `happy.png` and `sad.png`

content of `config/custom_emoji.txt`:
```
happy, /emoji/custom/happy.png, Tag1,Tag2
sad, /emoji/custom/sad.png, Tag1
foo, /emoji/custom/foo.png
```

The files should be PNG (APNG is okay with `.png` for `image/png` Content-type) and under 50kb for compatibility with mastodon.

## Emoji tags (groups)

Default tags are set in `config.exs`. To set your own tags, copy the structure to your secrets file (`prod.secret.exs` or `dev.secret.exs`) and edit it.
```elixir
config :pleroma, :emoji,
  shortcode_globs: ["/emoji/custom/**/*.png"],
  groups: [
    Finmoji: "/finmoji/128px/*-128.png",
    Custom: ["/emoji/*.png", "/emoji/custom/*.png"]
  ]
```

Order of the `groups` matters, so to override default tags just put your group on top of the list. E.g:
```elixir
config :pleroma, :emoji,
  shortcode_globs: ["/emoji/custom/**/*.png"],
  groups: [
    "Finmoji special": "/finmoji/128px/a_trusted_friend-128.png", # special file
    "Cirno": "/emoji/custom/cirno*.png", # png files in /emoji/custom/ which start with `cirno`
    "Special group": "/emoji/custom/special_folder/*.png", # png files in /emoji/custom/special_folder/
    "Another group": "/emoji/custom/special_folder/*/.png", # png files in /emoji/custom/special_folder/ subfolders
    Finmoji: "/finmoji/128px/*-128.png",
    Custom: ["/emoji/*.png", "/emoji/custom/*.png"]
  ]
```

Priority of tags assigns in emoji.txt and custom.txt:

`tag in file > special group setting in config.exs > default setting in config.exs`

Priority for globs:

`special group setting in config.exs > default setting in config.exs`
