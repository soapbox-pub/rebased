# Storing Remote Media

Pleroma does not store remote/federated media by default. The best way to achieve this is to change Nginx to keep its reverse proxy cache
forever and to activate the `MediaProxyWarmingPolicy` MRF policy in Pleroma which will automatically fetch all media through the proxy
as soon as the post is received by your instance.

## Nginx

We should be using `proxy_store` here I think???

```
    location ~ ^/(media|proxy) {
        proxy_cache        pleroma_media_cache;
        slice              1m;
        proxy_cache_key    $host$uri$is_args$args$slice_range;
        proxy_set_header   Range $slice_range;
        proxy_http_version 1.1;
        proxy_cache_valid  200 206 301 304 1h;
        proxy_cache_lock   on;
        proxy_ignore_client_abort on;
        proxy_buffering    on;
        chunked_transfer_encoding on;
        proxy_ignore_headers Cache-Control;
        proxy_hide_header  Cache-Control;
        proxy_pass         http://127.0.0.1:4000;
    }
```

## Pleroma

Add to your `prod.secret.exs`:

```
config :pleroma, :instance,
  rewrite_policy: [Pleroma.Web.ActivityPub.MRF.MediaProxyWarmingPolicy]
```
