# Storing Remote Media

Pleroma does not store remote/federated media by default. The best way to achieve this is to change Nginx to keep its reverse proxy cache
forever and to activate the `MediaProxyWarmingPolicy` MRF policy in Pleroma which will automatically fetch all media through the proxy
as soon as the post is received by your instance.

## Nginx

```
    proxy_cache_path /long/term/storage/path/pleroma-media-cache levels=1:2
        keys_zone=pleroma_media_cache:10m inactive=1y use_temp_path=off;

    location ~ ^/(media|proxy) {
        proxy_cache        pleroma_media_cache;
        slice              1m;
        proxy_cache_key    $host$uri$is_args$args$slice_range;
        proxy_set_header   Range $slice_range;
        proxy_http_version 1.1;
        proxy_cache_valid  206 301 302 304 1h;
        proxy_cache_valid  200 1y;
        proxy_cache_use_stale error timeout invalid_header updating;
        proxy_ignore_client_abort on;
        proxy_buffering    on;
        chunked_transfer_encoding on;
        proxy_ignore_headers Cache-Control Expires;
        proxy_hide_header  Cache-Control Expires;
        proxy_pass         http://127.0.0.1:4000;
    }
```

## Pleroma

Add to your `prod.secret.exs`:

```
config :pleroma, :instance,
  rewrite_policy: [Pleroma.Web.ActivityPub.MRF.MediaProxyWarmingPolicy]
```
