# Recommended varnishncsa logging format: '%h %l %u %t "%m %{X-Forwarded-Proto}i://%{Host}i%U%q %H" %s %b "%{Referer}i" "%{User-agent}i"'
# Please use Varnish 7.0+ for proper Range Requests / Chunked encoding support
vcl 4.1;
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
      set req.http.X-Forwarded-Proto = "http";
      set req.http.x-redir = "https://" + req.http.host + req.url;
      return (synth(750, ""));
    } else {
      set req.http.X-Forwarded-Proto = "https";
    }

    # Pipe if WebSockets request is coming through
    if (req.http.upgrade ~ "(?i)websocket") {
      return (pipe);
    }

    # Allow purging of the cache
    if (req.method == "PURGE") {
      if (!client.ip ~ purge) {
        return (synth(405,"Not allowed."));
      }
      return (purge);
    }
}

sub vcl_backend_response {
    # gzip text content
    if (beresp.http.content-type ~ "(text|text/css|application/x-javascript|application/javascript)") {
      set beresp.do_gzip = true;
    }

    # Retry broken backend responses.
    if (beresp.status == 503) {
      set bereq.http.X-Varnish-Backend-503 = "1";
      return (retry);
    }

    # Bypass cache for large files
    # 50000000 ~ 50MB
    if (std.integer(beresp.http.content-length, 0) > 50000000) {
       set beresp.uncacheable = true;
       return (deliver);
    }

    # Don't cache objects that require authentication
    if (beresp.http.Authorization && !beresp.http.Cache-Control ~ "public") {
      set beresp.uncacheable = true;
      return (deliver);
    }

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
}

# The synthetic response for 301 redirects
sub vcl_synth {
    if (resp.status == 750) {
      set resp.status = 301;
      set resp.http.Location = req.http.x-redir;
      return (deliver);
    }
}

# Ensure WebSockets through the pipe do not close prematurely
sub vcl_pipe {
    if (req.http.upgrade) {
      set bereq.http.upgrade = req.http.upgrade;
      set bereq.http.connection = req.http.connection;
    }
}

sub vcl_backend_fetch {
    # Be more lenient for slow servers on the fediverse
    if (bereq.url ~ "^/proxy/") {
      set bereq.first_byte_timeout = 300s;
    }

    if (bereq.retries == 0) {
        # Clean up the X-Varnish-Backend-503 flag that is used internally
        # to mark broken backend responses that should be retried.
        unset bereq.http.X-Varnish-Backend-503;
    } else {
        if (bereq.http.X-Varnish-Backend-503) {
            if (bereq.method != "POST" &&
              std.healthy(bereq.backend) &&
              bereq.retries <= 4) {
              # Flush broken backend response flag & try again.
              unset bereq.http.X-Varnish-Backend-503;
            } else {
              return (abandon);
            }
        }
    }
}

sub vcl_backend_error {
    # Retry broken backend responses.
    set bereq.http.X-Varnish-Backend-503 = "1";
    return (retry);
}
