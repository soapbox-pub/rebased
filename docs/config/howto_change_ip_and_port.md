# How to change the port or IP Pleroma listens to
To change the port or IP Pleroma listens to, head over to your generated config inside the Pleroma folder at config/prod.secret.exs and edit the following according to your needs.
```
config :pleroma, Pleroma.Web.Endpoint,
   [...]
   http: [ip: {127, 0, 0, 1}, port: 4000]
```
