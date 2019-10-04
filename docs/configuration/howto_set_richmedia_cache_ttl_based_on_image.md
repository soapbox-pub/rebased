# How to set rich media cache ttl based on image ttl
## Explanation

Richmedia are cached without the ttl but the rich media may have image which can expire, like aws signed url.
In such cases the old image url (expired) is returned from the media cache.

So to avoid such situation we can define a module that will set ttl based on image.
The module must adopt behaviour `Pleroma.Web.RichMedia.Parser.TTL`

### Example

```exs
defmodule MyModule do
  @behaviour Pleroma.Web.RichMedia.Parser.TTL

  @impl Pleroma.Web.RichMedia.Parser.TTL
  def ttl(data, url) do
    image_url = Map.get(data, :image)
    # do some parsing in the url and get the ttl of the image
    # return ttl is unix time
    parse_ttl_from_url(image_url)
  end
end
```

And update the config

```exs
config :pleroma, :rich_media,
  ttl_setters: [Pleroma.Web.RichMedia.Parser.TTL.AwsSignedUrl, MyModule]
```

> For reference there is a parser for AWS signed URL `Pleroma.Web.RichMedia.Parser.TTL.AwsSignedUrl`, it's enabled by default.
