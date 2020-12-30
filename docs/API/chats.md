# Chats

Chats are a way to represent an IM-style conversation between two actors. They are not the same as direct messages and they are not `Status`es, even though they have a lot in common.

## Why Chats?

There are no 'visibility levels' in ActivityPub, their definition is purely a Mastodon convention. Direct Messaging between users on the fediverse has mostly been modeled by using ActivityPub addressing following Mastodon conventions on normal `Note` objects. In this case, a 'direct message' would be a message that has no followers addressed and also does not address the special public actor, but just the recipients in the `to` field. It would still be a `Note` and is presented with other `Note`s as a `Status` in the API.

This is an awkward setup for a few reasons:

- As DMs generally still follow the usual `Status` conventions, it is easy to accidentally pull somebody into a DM thread by mentioning them. (e.g. "I hate @badguy so much")
- It is possible to go from a publicly addressed `Status` to a DM reply, back to public, then to a 'followers only' reply, and so on. This can be become very confusing, as it is unclear which user can see which part of the conversation.
- The standard `Status` format of implicit addressing also leads to rather ugly results if you try to display the messages as a chat, because all the recipients are always mentioned by name in the message.
- As direct messages are posted with the same api call (and usually same frontend component) as public messages, accidentally making a public message private or vice versa can happen easily. Client bugs can also lead to this, accidentally making private messages public.

As a measure to improve this situation, the `Conversation` concept and related Pleroma extensions were introduced. While it made it possible to work around a few of the issues, many of the problems remained and it didn't see much adoption because it was too complicated to use correctly. 

## Chats explained
For this reasons, Chats are a new and different entity, both in the API as well as in ActivityPub. A quick overview:

- Chats are meant to represent an instant message conversation between two actors. For now these are only 1-on-1 conversations, but the other actor can be a group in the future.
- Chat messages have the ActivityPub type `ChatMessage`. They are not `Note`s. Servers that don't understand them will just drop them.
- The only addressing allowed in `ChatMessage`s is one single ActivityPub actor in the `to` field.
- There's always only one Chat between two actors. If you start chatting with someone and later start a 'new' Chat, the old Chat will be continued.
- `ChatMessage`s are posted with a different api, making it very hard to accidentally send a message to the wrong person.
- `ChatMessage`s don't show up in the existing timelines.
- Chats can never go from private to public. They are always private between the two actors.

## Caveats

- Chats are NOT E2E encrypted (yet). Security is still the same as email.

## API

In general, the way to send a `ChatMessage` is to first create a `Chat`, then post a message to that `Chat`. `Group`s will later be supported by making them a sub-type of `Account`.

This is the overview of using the API. The API is also documented via OpenAPI, so you can view it and play with it by pointing SwaggerUI or a similar OpenAPI tool to `https://yourinstance.tld/api/openapi`.

### Creating or getting a chat.

To create or get an existing Chat for a certain recipient (identified by Account ID)
you can call:

`POST /api/v1/pleroma/chats/by-account-id/:account_id`

The account id is the normal FlakeId of the user
```
POST /api/v1/pleroma/chats/by-account-id/someflakeid
```

If you already have the id of a chat, you can also use

```
GET /api/v1/pleroma/chats/:id
```

There will only ever be ONE Chat for you and a given recipient, so this call
will return the same Chat if you already have one with that user.

Returned data:

```json
{
  "account": {
    "id": "someflakeid",
    "username": "somenick",
    ...
  },
  "id" : "1",
  "unread" : 2,
  "last_message" : {...}, // The last message in that chat
  "updated_at": "2020-04-21T15:11:46.000Z"
}
```

### Marking a chat as read

To mark a number of messages in a chat up to a certain message as read, you can use

`POST /api/v1/pleroma/chats/:id/read`


Parameters:
- last_read_id: Given this id, all chat messages until this one will be marked as read. Required.


Returned data:

```json
{
  "account": {
    "id": "someflakeid",
    "username": "somenick",
    ...
  },
  "id" : "1",
  "unread" : 0,
  "updated_at": "2020-04-21T15:11:46.000Z"
}
```

### Marking a single chat message as read

To set the `unread` property of a message to `false`

`POST /api/v1/pleroma/chats/:id/messages/:message_id/read`

Returned data:

The modified chat message

### Getting a list of Chats

`GET /api/v1/pleroma/chats`

This will return a list of chats that you have been involved in, sorted by their
last update (so new chats will be at the top).

Parameters:

- with_muted: Include chats from muted users (boolean).

Returned data:

```json
[
   {
      "account": {
        "id": "someflakeid",
        "username": "somenick",
        ...
      },
      "id" : "1",
      "unread" : 2,
      "last_message" : {...}, // The last message in that chat
      "updated_at": "2020-04-21T15:11:46.000Z"
   }
]
```

The recipient of messages that are sent to this chat is given by their AP ID.
No pagination is implemented for now.

### Getting the messages for a Chat

For a given Chat id, you can get the associated messages with

`GET /api/v1/pleroma/chats/:id/messages`

This will return all messages, sorted by most recent to least recent. The usual
pagination options are implemented.

Returned data:

```json
[
  {
    "account_id": "someflakeid",
    "chat_id": "1",
    "content": "Check this out :firefox:",
    "created_at": "2020-04-21T15:11:46.000Z",
    "emojis": [
      {
        "shortcode": "firefox",
        "static_url": "https://dontbulling.me/emoji/Firefox.gif",
        "url": "https://dontbulling.me/emoji/Firefox.gif",
        "visible_in_picker": false
      }
    ],
    "id": "13",
    "unread": true
  },
  {
    "account_id": "someflakeid",
    "chat_id": "1",
    "content": "Whats' up?",
    "created_at": "2020-04-21T15:06:45.000Z",
    "emojis": [],
    "id": "12",
    "unread": false,
    "idempotency_key": "75442486-0874-440c-9db1-a7006c25a31f"
  }
]
```

- idempotency_key: The copy of the `idempotency-key` HTTP request header that can be used for optimistic message sending. Included only during the first few minutes after the message creation.

### Posting a chat message

Posting a chat message for given Chat id works like this:

`POST /api/v1/pleroma/chats/:id/messages`

Parameters:
- content: The text content of the message. Optional if media is attached.
- media_id: The id of an upload that will be attached to the message.

Currently, no formatting beyond basic escaping and emoji is implemented.

Returned data:

```json
{
  "account_id": "someflakeid",
  "chat_id": "1",
  "content": "Check this out :firefox:",
  "created_at": "2020-04-21T15:11:46.000Z",
  "emojis": [
    {
      "shortcode": "firefox",
      "static_url": "https://dontbulling.me/emoji/Firefox.gif",
      "url": "https://dontbulling.me/emoji/Firefox.gif",
      "visible_in_picker": false
    }
  ],
  "id": "13",
  "unread": false
}
```

### Deleting a chat message

Deleting a chat message for given Chat id works like this:

`DELETE /api/v1/pleroma/chats/:chat_id/messages/:message_id`

Returned data is the deleted message.

### Notifications

There's a new `pleroma:chat_mention` notification, which has this form. It is not given out in the notifications endpoint by default, you need to explicitly request it with `include_types[]=pleroma:chat_mention`:

```json
{
  "id": "someid",
  "type": "pleroma:chat_mention",
  "account": { ... } // User account of the sender,
  "chat_message": {
    "chat_id": "1",
    "id": "10",
    "content": "Hello",
    "account_id": "someflakeid",
    "unread": false
  },
  "created_at": "somedate"
}
```

### Streaming

There is an additional `user:pleroma_chat` stream. Incoming chat messages will make the current chat be sent to this `user` stream. The `event` of an incoming chat message is `pleroma:chat_update`. The payload is the updated chat with the incoming chat message in the `last_message` field.

### Web Push

If you want to receive push messages for this type, you'll need to add the `pleroma:chat_mention` type to your alerts in the push subscription.
