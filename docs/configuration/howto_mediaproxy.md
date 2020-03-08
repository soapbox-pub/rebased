# How to activate mediaproxy
## Explanation

Without the `mediaproxy` function, Pleroma doesn't store any remote content like pictures, video etc. locally. So every time you open Pleroma, the content is loaded from the source server, from where the post is coming. This can result in slowly loading content or/and increased bandwidth usage on the source server.
With the `mediaproxy` function you can use nginx to cache this content, so users can access it faster, because it's loaded from your server.

## Activate it

* Edit your nginx config and add the following location: 
```
location /proxy {
        proxy_cache pleroma_media_cache;
        proxy_cache_lock on;
        proxy_pass http://localhost:4000;
}
```
Also add the following on top of the configuration, outside of the `server` block:
```
proxy_cache_path /tmp/pleroma-media-cache levels=1:2 keys_zone=pleroma_media_cache:10m max_size=10g inactive=720m use_temp_path=off;
```
If you came here from one of the installation guides, take a look at the example configuration `/installation/pleroma.nginx`, where this part is already included.

* Append the following to your `prod.secret.exs` or `dev.secret.exs` (depends on which mode your instance is running):
```
config :pleroma, :media_proxy,
      enabled: true,
      proxy_opts: [
            redirect_on_failure: true
      ]
      #base_url: "https://cache.pleroma.social"
```
If you want to use a subdomain to serve the files, uncomment `base_url`, change the url and add a comma after `true` in the previous line.

* Restart nginx and Pleroma
