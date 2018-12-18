# Authentication

Requests that require it can be authenticated with [an OAuth token](https://tools.ietf.org/html/rfc6749), the `_pleroma_key` cookie, or [HTTP Basic Authentication](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Authorization).

# Request parameters

Request parameters can be passed via [query strings](https://en.wikipedia.org/wiki/Query_string) or as [form data](https://www.w3.org/TR/html401/interact/forms.html). Files must be uploaded as `multipart/form-data`.

# Endpoints

## `/api/pleroma/emoji`
### Lists the custom emoji on that server.
* Method: `GET`
* Authentication: not required
* Params: none
* Response: JSON
* Example response: `{"kalsarikannit_f":"/finmoji/128px/kalsarikannit_f-128.png","perkele":"/finmoji/128px/perkele-128.png","blobdab":"/emoji/blobdab.png","happiness":"/finmoji/128px/happiness-128.png"}`

## `/api/pleroma/follow_import`
### Imports your follows, for example from a Mastodon CSV file.
* Method: `POST`
* Authentication: required
* Params:
    * `list`: STRING or FILE containing a whitespace-separated list of accounts to follow
    * Response: HTTP 200 on success, 500 on error
    * Note: Users that can't be followed are silently skipped.
