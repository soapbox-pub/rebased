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

# Emoji tags

Changing default tags:

* For `Finmoji`, `emoji.txt` and `custom_emoji.txt` are added default tags, which can be configured in the `config.exs`:
* For emoji loaded from globs:
    - `priv/static/emoji/custom/*.png` - `custom_tag`, can be configured in `config.exs`
    - `priv/static/emoji/custom/TagName/*.png` - folder (`TagName`) is used as tag


```
config :pleroma, :emoji,
  shortcode_globs: ["/emoji/custom/**/*.png"],
  custom_tag: "Custom", # Default tag for emoji in `priv/static/emoji/custom` path
  finmoji_tag: "Finmoji", # Default tag for Finmoji
  emoji_tag: "Emoji", # Default tag for emoji.txt
  custom_emoji_tag: "Custom" # Default tag for custom_emoji.txt
```
