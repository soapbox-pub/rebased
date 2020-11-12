# Prometheus Metrics

Pleroma includes support for exporting metrics via the [prometheus_ex](https://github.com/deadtrickster/prometheus.ex) library.

Config example:

```
config :prometheus, Pleroma.Web.Endpoint.MetricsExporter,
  enabled: true,
  auth: {:basic, "myusername", "mypassword"},
  ip_whitelist: ["127.0.0.1"],
  path: "/api/pleroma/app_metrics",
  format: :text
```

* `enabled` (Pleroma extension) enables the endpoint
* `ip_whitelist` (Pleroma extension) could be used to restrict access only to specified IPs
* `auth` sets the authentication (`false` for no auth; configurable to HTTP Basic Auth, see [prometheus-plugs](https://github.com/deadtrickster/prometheus-plugs#exporting) documentation)
* `format` sets the output format (`:text` or `:protobuf`)
* `path` sets the path to app metrics page 


## `/api/pleroma/app_metrics`

### Exports Prometheus application metrics

* Method: `GET`
* Authentication: not required by default (see configuration options above)
* Params: none
* Response: text

## Grafana

### Config example

The following is a config example to use with [Grafana](https://grafana.com)

```
  - job_name: 'beam'
    metrics_path: /api/pleroma/app_metrics
    scheme: https
    static_configs:
    - targets: ['pleroma.soykaf.com']
```
