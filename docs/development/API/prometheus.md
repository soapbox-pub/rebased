# Prometheus / OpenTelemetry Metrics

Pleroma includes support for exporting metrics via the [prom_ex](https://github.com/akoutmos/prom_ex) library.
The metrics are exposed by a dedicated webserver/port to improve privacy and security.

Config example:

```
config :pleroma, Pleroma.PromEx,
  disabled: false,
  manual_metrics_start_delay: :no_delay,
  drop_metrics_groups: [],
  grafana: [
    host: System.get_env("GRAFANA_HOST", "http://localhost:3000"),
    auth_token: System.get_env("GRAFANA_TOKEN"),
    upload_dashboards_on_start: false,
    folder_name: "BEAM",
    annotate_app_lifecycle: true
  ],
  metrics_server: [
    port: 4021,
    path: "/metrics",
    protocol: :http,
    pool_size: 5,
    cowboy_opts: [],
    auth_strategy: :none
  ],
  datasource: "Prometheus"

```

PromEx supports the ability to automatically publish dashboards to your Grafana server as well as register Annotations. If you do not wish to configure this capability you must generate the dashboard JSON files and import them directly. You can find the mix commands in the upstream [documentation](https://hexdocs.pm/prom_ex/Mix.Tasks.PromEx.Dashboard.Export.html). You can find the list of modules enabled in Pleroma for which you should generate dashboards for by examining the contents of the `lib/pleroma/prom_ex.ex` module.

## prometheus.yml

The following is a bare minimum config example to use with [Prometheus](https://prometheus.io) or Prometheus-compatible software like [VictoriaMetrics](https://victoriametrics.com).

```
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'pleroma'
    scheme: http
    static_configs:
    - targets: ['pleroma.soykaf.com:4021']
```
