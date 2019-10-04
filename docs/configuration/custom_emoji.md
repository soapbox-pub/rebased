# Custom Emoji

Before you add your own custom emoji, check if they are available in an existing pack.
See `Mix.Tasks.Pleroma.Emoji` for information about emoji packs.

To add custom emoji:

* Create the `STATIC-DIR/emoji/` directory if it doesn't exist
  (`STATIC-DIR` is configurable, `instance/static/` by default)
* Create a directory with whatever name you want (custom is a good name to show the purpose of it).
  This will create a local emoji pack.
* Put your `.png` emoji files in that directory. In case of conflicts, you can create an `emoji.txt`
  file in that directory and specify a custom shortcode using the following format:
  `shortcode, file-path, tag1, tag2, etc`. One emoji per line. Note that if you do so,
  you'll have to list all other emojis in the pack too.
* Either restart pleroma or connect to the iex session pleroma's running and
  run `Pleroma.Emoji.reload/0` in it.

Example:

image files (in `instance/static/emoji/custom`): `happy.png` and `sad.png`

content of `emoji.txt`:
```
happy, /emoji/custom/happy.png, Tag1,Tag2
sad, /emoji/custom/sad.png, Tag1
foo, /emoji/custom/foo.png
```

The files should be PNG (APNG is okay with `.png` for `image/png` Content-type) and under 50kb for compatibility with mastodon.

Default file extentions and locations for emojis are set in `config.exs`. To use different locations or file-extentions, add the `shortcode_globs` to your secrets file (`prod.secret.exs` or `dev.secret.exs`) and edit it. Note that not all fediverse-software will show emojis with other file extentions:
```elixir
config :pleroma, :emoji, shortcode_globs: ["/emoji/custom/**/*.png", "/emoji/custom/**/*.gif"]
```

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
