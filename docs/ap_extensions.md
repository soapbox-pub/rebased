# ChatMessages

ChatMessages are the messages sent in 1-on-1 chats. They are similar to
`Note`s, but the addresing is done by having a single AP actor in the `to`
field. Addressing multiple actors is not allowed. These messages are always
private, there is no public version of them. They are created with a `Create`
activity.

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
