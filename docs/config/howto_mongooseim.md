# Configuring MongooseIM (XMPP Server) to use Pleroma for authentication

If you want to give your Pleroma users an XMPP (chat) account, you can configure [MongooseIM](https://github.com/esl/MongooseIM) to use your Pleroma server for user authentication, automatically giving every local user an XMPP account.

In general, you just have to follow the configuration described at [https://mongooseim.readthedocs.io/en/latest/authentication-backends/HTTP-authentication-module/](https://mongooseim.readthedocs.io/en/latest/authentication-backends/HTTP-authentication-module/) and do these changes to your mongooseim.cfg.

1. Set the auth_method to `{auth_method, http}`.
2. Add the http auth pool like this: `{http, global, auth, [{workers, 50}], [{server, "https://yourpleromainstance.com"}]}`

Restart your MongooseIM server, your users should now be able to connect with their Pleroma credentials.
