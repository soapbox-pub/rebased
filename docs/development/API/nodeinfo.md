# Nodeinfo

See also [the Nodeinfo standard](https://nodeinfo.diaspora.software/).

## `/.well-known/nodeinfo`
### The well-known path
* Method: `GET`
* Authentication: not required
* Params: none
* Response: JSON
* Example response:
```json
{
   "links":[
      {
         "href":"https://example.com/nodeinfo/2.0.json",
         "rel":"http://nodeinfo.diaspora.software/ns/schema/2.0"
      },
      {
         "href":"https://example.com/nodeinfo/2.1.json",
         "rel":"http://nodeinfo.diaspora.software/ns/schema/2.1"
      }
   ]
}
```

## `/nodeinfo/2.0.json`
### Nodeinfo 2.0
* Method: `GET`
* Authentication: not required
* Params: none
* Response: JSON
* Example response:
```json
{
   "metadata":{
      "accountActivationRequired":false,
      "features":[
         "pleroma_api",
         "mastodon_api",
         "mastodon_api_streaming",
         "polls",
         "pleroma_explicit_addressing",
         "shareable_emoji_packs",
         "multifetch",
         "pleroma:api/v1/notifications:include_types_filter",
         "chat",
         "shout",
         "relay",
         "pleroma_emoji_reactions",
         "pleroma_chat_messages"
      ],
      "federation":{
         "enabled":true,
         "exclusions":false,
         "mrf_hashtag":{
            "federated_timeline_removal":[
               
            ],
            "reject":[
               
            ],
            "sensitive":[
               "nsfw"
            ]
         },
         "mrf_object_age":{
            "actions":[
               "delist",
               "strip_followers"
            ],
            "threshold":604800
         },
         "mrf_policies":[
            "ObjectAgePolicy",
            "TagPolicy",
            "HashtagPolicy"
         ],
         "quarantined_instances":[
            
         ]
      },
      "fieldsLimits":{
         "maxFields":10,
         "maxRemoteFields":20,
         "nameLength":512,
         "valueLength":2048
      },
      "invitesEnabled":false,
      "mailerEnabled":false,
      "nodeDescription":"Pleroma: An efficient and flexible fediverse server",
      "nodeName":"Example",
      "pollLimits":{
         "max_expiration":31536000,
         "max_option_chars":200,
         "max_options":20,
         "min_expiration":0
      },
      "postFormats":[
         "text/plain",
         "text/html",
         "text/markdown",
         "text/bbcode"
      ],
      "private":false,
      "restrictedNicknames":[
         ".well-known",
         "~",
         "about",
         "activities",
         "api",
         "auth",
         "check_password",
         "dev",
         "friend-requests",
         "inbox",
         "internal",
         "main",
         "media",
         "nodeinfo",
         "notice",
         "oauth",
         "objects",
         "ostatus_subscribe",
         "pleroma",
         "proxy",
         "push",
         "registration",
         "relay",
         "settings",
         "status",
         "tag",
         "user-search",
         "user_exists",
         "users",
         "web",
         "verify_credentials",
         "update_credentials",
         "relationships",
         "search",
         "confirmation_resend",
         "mfa"
      ],
      "skipThreadContainment":true,
      "staffAccounts":[
         "https://example.com/users/admin",
         "https://example.com/users/staff"
      ],
      "suggestions":{
         "enabled":false
      },
      "uploadLimits":{
         "avatar":2000000,
         "background":4000000,
         "banner":4000000,
         "general":16000000
      }
   },
   "openRegistrations":true,
   "protocols":[
      "activitypub"
   ],
   "services":{
      "inbound":[
         
      ],
      "outbound":[
         
      ]
   },
   "software":{
      "name":"pleroma",
      "version":"2.4.1"
   },
   "usage":{
      "localPosts":27,
      "users":{
         "activeHalfyear":129,
         "activeMonth":70,
         "total":235
      }
   },
   "version":"2.0"
}
```

## `/nodeinfo/2.1.json`
### Nodeinfo 2.1
* Method: `GET`
* Authentication: not required
* Params: none
* Response: JSON
* Example response:
```json
{
   "metadata":{
      "accountActivationRequired":false,
      "features":[
         "pleroma_api",
         "mastodon_api",
         "mastodon_api_streaming",
         "polls",
         "pleroma_explicit_addressing",
         "shareable_emoji_packs",
         "multifetch",
         "pleroma:api/v1/notifications:include_types_filter",
         "chat",
         "shout",
         "relay",
         "pleroma_emoji_reactions",
         "pleroma_chat_messages"
      ],
      "federation":{
         "enabled":true,
         "exclusions":false,
         "mrf_hashtag":{
            "federated_timeline_removal":[
               
            ],
            "reject":[
               
            ],
            "sensitive":[
               "nsfw"
            ]
         },
         "mrf_object_age":{
            "actions":[
               "delist",
               "strip_followers"
            ],
            "threshold":604800
         },
         "mrf_policies":[
            "ObjectAgePolicy",
            "TagPolicy",
            "HashtagPolicy"
         ],
         "quarantined_instances":[
            
         ]
      },
      "fieldsLimits":{
         "maxFields":10,
         "maxRemoteFields":20,
         "nameLength":512,
         "valueLength":2048
      },
      "invitesEnabled":false,
      "mailerEnabled":false,
      "nodeDescription":"Pleroma: An efficient and flexible fediverse server",
      "nodeName":"Example",
      "pollLimits":{
         "max_expiration":31536000,
         "max_option_chars":200,
         "max_options":20,
         "min_expiration":0
      },
      "postFormats":[
         "text/plain",
         "text/html",
         "text/markdown",
         "text/bbcode"
      ],
      "private":false,
      "restrictedNicknames":[
         ".well-known",
         "~",
         "about",
         "activities",
         "api",
         "auth",
         "check_password",
         "dev",
         "friend-requests",
         "inbox",
         "internal",
         "main",
         "media",
         "nodeinfo",
         "notice",
         "oauth",
         "objects",
         "ostatus_subscribe",
         "pleroma",
         "proxy",
         "push",
         "registration",
         "relay",
         "settings",
         "status",
         "tag",
         "user-search",
         "user_exists",
         "users",
         "web",
         "verify_credentials",
         "update_credentials",
         "relationships",
         "search",
         "confirmation_resend",
         "mfa"
      ],
      "skipThreadContainment":true,
      "staffAccounts":[
         "https://example.com/users/admin",
         "https://example.com/users/staff"
      ],
      "suggestions":{
         "enabled":false
      },
      "uploadLimits":{
         "avatar":2000000,
         "background":4000000,
         "banner":4000000,
         "general":16000000
      }
   },
   "openRegistrations":true,
   "protocols":[
      "activitypub"
   ],
   "services":{
      "inbound":[
         
      ],
      "outbound":[
         
      ]
   },
   "software":{
      "name":"pleroma",
      "repository":"https://git.pleroma.social/pleroma/pleroma",
      "version":"2.4.1"
   },
   "usage":{
      "localPosts":27,
      "users":{
         "activeHalfyear":129,
         "activeMonth":70,
         "total":235
      }
   },
   "version":"2.1"
}
```

