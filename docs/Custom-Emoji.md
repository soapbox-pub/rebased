# Custom emoji

To add custom emoji:
* Add the image file(s) to `priv/static/emoji/custom`
* In case of conflicts: add the desired shortcode with the path to `config/custom_emoji.txt`, comma-separated and one per line
* Force recompilation (``mix clean && mix compile``)

Example:

image files (in `/priv/static/emoji/custom`): `happy.png` and `sad.png`

content of `config/custom_emoji.txt`:
```
happy, /emoji/custom/happy.png
sad, /emoji/custom/sad.png
```

The files should be PNG (APNG is okay with `.png` for `image/png` Content-type) and under 50kb for compatibility with mastodon.
