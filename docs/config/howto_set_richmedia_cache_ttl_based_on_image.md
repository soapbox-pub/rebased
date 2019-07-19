# How to set rich media cache ttl based on image ttl
## Explanation

Richmedia are cached without the ttl but the rich media may have image which can expire, like aws signed url.
In such cases the old image url (expired) is returned from the media cache.

So to avoid such situation we can define a moddule that will set ttl based on image.

The module must have a `run` function and it should be registered in the config.

### Example

```exs
defmodule MyModule do
  def run(data, url) do
    image_url = Map.get(data, :image)
    # do some parsing in the url and get the ttl of the image
    # ttl is unix time
    ttl = parse_ttl_from_url(image_url)  
    Cachex.expire_at(:rich_media_cache, url, ttl * 1000)
  end
end
```

And update the config

```exs
config :pleroma, :rich_media,
  ttl_setters: [Pleroma.Web.RichMedia.Parser.TTL.AwsSignedUrl, MyModule]
```

> For reference there is a parser for AWS signed URL `Pleroma.Web.RichMedia.Parser.TTL.AwsSignedUrl`, it's enabled by default.
