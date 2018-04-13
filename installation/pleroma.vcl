vcl 4.0;
import std;

backend default {
    .host = "127.0.0.1";
    .port = "4000";
}

# ACL for IPs that are allowed to PURGE data from the cache
acl purge {
    "127.0.0.1";
}

sub vcl_recv {
    # Redirect HTTP to HTTPS
    if (std.port(server.ip) != 443) {
        set req.http.x-redir = "https://" + req.http.host + req.url;
        return (synth(750, ""));
    }

    # Pipe if WebSockets request is coming through
    if (req.http.upgrade ~ "(?i)websocket") {
        return (pipe);
    }

    # Allow purging of the cache
    if (req.method == "PURGE") {
        if (!client.ip ~ purge) {
          return(synth(405,"Not allowed."));
        }
        return(purge);
    }

    # Pleroma MediaProxy - strip headers that will affect caching
    if (req.url ~ "^/proxy/") {
        unset req.http.Cookie;
        unset req.http.Authorization;
        unset req.http.Accept;
        return (hash);
    }

    # Hack to enable a Terms of Service page missing from Pleroma
    if (req.url ~ "^/about/more$") {
        set req.http.x-redir = "https://" + req.http.host + "/static/terms-of-service.html";
        return (synth(750, ""));
    }

    # Strip headers that will affect caching from all other static content
    # This also permits caching of individual toots and AP Activities
    if ((req.url ~ "^/(media|notice|static)/") ||
    (req.url ~ "(?i)\.(html|js|css|jpg|jpeg|png|gif|gz|tgz|bz2|tbz|mp3|ogg|svg|swf|ttf|pdf|woff|woff2)$"))
    {
      unset req.http.Cookie;
      unset req.http.Authorization;
      return (hash);
    }

    # Everything else should just be piped to Pleroma
    return (pipe);
}

sub vcl_backend_response {
    # gzip text content
    if (beresp.http.content-type ~ "(text|text/css|application/x-javascript|application/javascript)") {
      set beresp.do_gzip = true;
    }

    # etags are bad
    unset beresp.http.etag;

    # Don't cache objects that require authentication
    if (beresp.http.Authorization && !beresp.http.Cache-Control ~ "public") {
      set beresp.uncacheable = true;
      return (deliver);
    }

    # Default object caching of 86400s;
    set beresp.ttl = 86400s;
    # Allow serving cached content for 6h in case backend goes down
    set beresp.grace = 6h;

    # Do not cache 5xx responses
    if (beresp.status == 500 || beresp.status == 502 || beresp.status == 503 || beresp.status == 504) {
      set beresp.uncacheable = true;
      return (abandon);
    }

    # Do not cache redirects and errors
    if ((beresp.status >= 300) && (beresp.status < 500)) {
        set beresp.uncacheable = true;
        set beresp.ttl = 30s;
        return (deliver);
    }

    # Pleroma MediaProxy internally sets headers properly
    if (bereq.url ~ "^/proxy/") {
      return (deliver);
    }

    # Strip cache-restricting headers from Pleroma on static content that we want to cache
    # Also enable streaming of cached content to clients (no waiting for Varnish to complete backend fetch)
    if ((bereq.url ~ "^/(notice)/") ||
    (bereq.url ~ "(?i)\.(js|css|jpg|jpeg|png|gif|gz|tgz|bz2|tbz|mp3|ogg|svg|swf|ttf|pdf|woff|woff2)$"))
    {
      unset beresp.http.set-cookie;
      unset beresp.http.Cache-Control;
      unset beresp.http.x-request-id;
      set beresp.http.Cache-Control = "public, max-age=86400";
      set beresp.do_stream = true;
    }
}

# The synthetic response for 301 redirects
sub vcl_synth {
    if (resp.status == 750) {
      set resp.status = 301;
      set resp.http.Location = req.http.x-redir;
      return(deliver);
    }
}

# Ensure WebSockets through the pipe do not close prematurely
sub vcl_pipe {
    if (req.http.upgrade) {
        set bereq.http.upgrade = req.http.upgrade;
        set bereq.http.connection = req.http.connection;
    }
}
