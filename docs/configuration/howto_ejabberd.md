# Configuring Ejabberd (XMPP Server) to use Pleroma for authentication

If you want to give your Pleroma users an XMPP (chat) account, you can configure [Ejabberd](https://github.com/processone/ejabberd) to use your Pleroma server for user authentication, automatically giving every local user an XMPP account.

In general, you just have to follow the configuration described at [https://docs.ejabberd.im/admin/configuration/authentication/#external-script](https://docs.ejabberd.im/admin/configuration/authentication/#external-script). Please read this section carefully. 

Copy the script below to suitable path on your system and set owner and permissions. Also do not forget adjusting `PLEROMA_HOST` and `PLEROMA_PORT`, if necessary.

```bash
cp pleroma_ejabberd_auth.py /etc/ejabberd/pleroma_ejabberd_auth.py
chown ejabberd /etc/ejabberd/pleroma_ejabberd_auth.py
chmod 700 /etc/ejabberd/pleroma_ejabberd_auth.py
```

Set external auth params in ejabberd.yaml file:

```bash
auth_method: [external]
extauth_program: "python3 /etc/ejabberd/pleroma_ejabberd_auth.py"
extauth_instances: 3
auth_use_cache: false
```

Restart / reload your ejabberd service.

After restarting your Ejabberd server, your users should now be able to connect with their Pleroma credentials.


```python
import sys
import struct
import http.client
from base64 import b64encode
import logging


PLEROMA_HOST = "127.0.0.1"
PLEROMA_PORT = "4000"
AUTH_ENDPOINT = "/api/v1/accounts/verify_credentials"
USER_ENDPOINT = "/api/v1/accounts"
LOGFILE = "/var/log/ejabberd/pleroma_auth.log"

logging.basicConfig(filename=LOGFILE, level=logging.INFO)


# Pleroma functions
def create_connection():
    return http.client.HTTPConnection(PLEROMA_HOST, PLEROMA_PORT)


def verify_credentials(user: str, password: str) -> bool:
    user_pass_b64 = b64encode("{}:{}".format(
        user, password).encode('utf-8')).decode("ascii")
    params = {}
    headers = {
        "Authorization": "Basic {}".format(user_pass_b64)
    }

    try:
        conn = create_connection()
        conn.request("GET", AUTH_ENDPOINT, params, headers)

        response = conn.getresponse()
        if response.status == 200:
            return True

        return False
    except Exception as e:
        logging.info("Can not connect: %s", str(e))
        return False


def does_user_exist(user: str) -> bool:
    conn = create_connection()
    conn.request("GET", "{}/{}".format(USER_ENDPOINT, user))

    response = conn.getresponse()
    if response.status == 200:
        return True

    return False


def auth(username: str, server: str, password: str) -> bool:
    return verify_credentials(username, password)


def isuser(username, server):
    return does_user_exist(username)


def read():
    (pkt_size,) = struct.unpack('>H', bytes(sys.stdin.read(2), encoding='utf8'))
    pkt = sys.stdin.read(pkt_size)
    cmd = pkt.split(':')[0]
    if cmd == 'auth':
        username, server, password = pkt.split(':', 3)[1:]
        write(auth(username, server, password))
    elif cmd == 'isuser':
        username, server = pkt.split(':', 2)[1:]
        write(isuser(username, server))
    elif cmd == 'setpass':
        # u, s, p = pkt.split(':', 3)[1:]
        write(False)
    elif cmd == 'tryregister':
        # u, s, p = pkt.split(':', 3)[1:]
        write(False)
    elif cmd == 'removeuser':
        # u, s = pkt.split(':', 2)[1:]
        write(False)
    elif cmd == 'removeuser3':
        # u, s, p = pkt.split(':', 3)[1:]
        write(False)
    else:
        write(False)


def write(result):
    if result:
        sys.stdout.write('\x00\x02\x00\x01')
    else:
        sys.stdout.write('\x00\x02\x00\x00')
    sys.stdout.flush()


if __name__ == "__main__":
    logging.info("Starting pleroma ejabberd auth daemon...")
    while True:
        try:
            read()
        except Exception as e:
            logging.info(
                "Error while processing data from ejabberd %s", str(e))
            pass

```