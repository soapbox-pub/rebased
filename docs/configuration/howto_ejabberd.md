# Configuring Ejabberd (XMPP Server) to use Pleroma for authentication

If you want to give your Pleroma users an XMPP (chat) account, you can configure [Ejabberd](https://github.com/processone/ejabberd) to use your Pleroma server for user authentication, automatically giving every local user an XMPP account.

In general, you just have to follow the configuration described at [https://docs.ejabberd.im/admin/configuration/authentication/#external-script](https://docs.ejabberd.im/admin/configuration/authentication/#external-script). Please read this section carefully. 

To get the external script please go to [https://github.com/alirizakeles/ejabberd-pleroma-auth](https://github.com/alirizakeles/ejabberd-pleroma-auth) and follow the steps described in README.

After restarting your Ejabberd server, your users should now be able to connect with their Pleroma credentials.
