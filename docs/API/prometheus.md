# Prometheus Metrics

Pleroma includes support for exporting metrics via the [prometheus_ex](https://github.com/deadtrickster/prometheus.ex) library.

## `/api/pleroma/app_metrics`
### Exports Prometheus application metrics
* Method: `GET`
* Authentication: not required
* Params: none
* Response: JSON

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
