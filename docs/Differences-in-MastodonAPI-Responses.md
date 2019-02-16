# Differences in Mastodon API responses from vanilla Mastodon

## Flake IDs

Pleroma uses 128-bit ids as opposed to Mastodon's 64 bits. However just like Mastodon's ids they are sortable strings

## Attachment cap

Some apps operate under the assumption that no more than 4 attachments ccan be returned, however Pleroma can return any amount of attachments
