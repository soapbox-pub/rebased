# AP Extensions
## Actor endpoints

The following endpoints are additionally present into our actors.

- `oauthRegistrationEndpoint` (`http://litepub.social/ns#oauthRegistrationEndpoint`)
- `uploadMedia` (`https://www.w3.org/ns/activitystreams#uploadMedia`)

### oauthRegistrationEndpoint

Points to MastodonAPI `/api/v1/apps` for now.

See <https://docs.joinmastodon.org/methods/apps/>

### uploadMedia

Inspired by <https://www.w3.org/wiki/SocialCG/ActivityPub/MediaUpload>, it is part of the ActivityStreams namespace because it used to be part of the ActivityPub specification and got removed from it.

Content-Type: multipart/form-data

Parameters:
- (required) `file`: The file being uploaded
- (optionnal) `description`: A plain-text description of the media, for accessibility purposes.

Response: HTTP 201 Created with the object into the body, no `Location` header provided as it doesn't have an `id`

The object given in the reponse should then be inserted into an Object's `attachment` field.

## ChatMessages

`ChatMessage`s are the messages sent in 1-on-1 chats. They are similar to
`Note`s, but the addresing is done by having a single AP actor in the `to`
field. Addressing multiple actors is not allowed. These messages are always
private, there is no public version of them. They are created with a `Create`
activity.

They are part of the `litepub` namespace as `http://litepub.social/ns#ChatMessage`.

Example:

```json
{
  "actor": "http://2hu.gensokyo/users/raymoo",
  "id": "http://2hu.gensokyo/objects/1",
  "object": {
    "attributedTo": "http://2hu.gensokyo/users/raymoo",
    "content": "You expected a cute girl? Too bad.",
    "id": "http://2hu.gensokyo/objects/2",
    "published": "2020-02-12T14:08:20Z",
    "to": [
      "http://2hu.gensokyo/users/marisa"
    ],
    "type": "ChatMessage"
  },
  "published": "2018-02-12T14:08:20Z",
  "to": [
    "http://2hu.gensokyo/users/marisa"
  ],
  "type": "Create"
}
```

This setup does not prevent multi-user chats, but these will have to go through
a `Group`, which will be the recipient of the messages and then `Announce` them
to the users in the `Group`.
