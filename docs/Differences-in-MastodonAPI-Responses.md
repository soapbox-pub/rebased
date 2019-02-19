# Differences in Mastodon API responses from vanilla Mastodon

A Pleroma instance can be identified by "<Mastodon version> (compatible; Pleroma <version>)" present in `version` field in response from `/api/v1/instance` 

## Flake IDs

Pleroma uses 128-bit ids as opposed to Mastodon's 64 bits. However just like Mastodon's ids they are sortable strings

## Attachment cap

Some apps operate under the assumption that no more than 4 attachments can be returned or uploaded. Pleroma however does not enforce any limits on attachment count neither when returning the status object nor when posting.
