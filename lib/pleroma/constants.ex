# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Constants do
  use Const

  const(as_public, do: "https://www.w3.org/ns/activitystreams#Public")

  const(object_internal_fields,
    do: [
      "reactions",
      "reaction_count",
      "likes",
      "like_count",
      "announcements",
      "announcement_count",
      "emoji",
      "context_id",
      "deleted_activity_id",
      "pleroma_internal",
      "generator",
      "rules",
      "assigned_account",
      "rules",
      "content_type",
      "language",
      "participations",
      "participation_count",
      "participation_request_count",
      "location_id"
    ]
  )

  const(static_only_files,
    do:
      ~w(index.html robots.txt static static-fe finmoji emoji packs sounds images instance sw.js sw-pleroma.js favicon.png schemas doc embed.js embed.css)
  )

  const(status_updatable_fields,
    do: [
      "source",
      "tag",
      "updated",
      "emoji",
      "content",
      "summary",
      "sensitive",
      "attachment",
      "generator",
      "language",
      "startTime",
      "endTime",
      "location",
      "location_id",
      "location_provider",
      "name"
    ]
  )

  const(status_object_types,
    do: [
      "Note",
      "Question",
      "Audio",
      "Video",
      "Event",
      "Article",
      "Page"
    ]
  )

  const(updatable_object_types,
    do: [
      "Note",
      "Question",
      "Audio",
      "Video",
      "Event",
      "Article",
      "Page"
    ]
  )

  const(actor_types,
    do: [
      "Application",
      "Group",
      "Organization",
      "Person",
      "Service"
    ]
  )

  const(allowed_user_actor_types,
    do: [
      "Person",
      "Service",
      "Group"
    ]
  )

  # basic regex, just there to weed out potential mistakes
  # https://datatracker.ietf.org/doc/html/rfc2045#section-5.1
  const(mime_regex,
    do: ~r/^[^[:cntrl:] ()<>@,;:\\"\/\[\]?=]+\/[^[:cntrl:] ()<>@,;:\\"\/\[\]?=]+(; .*)?$/
  )

  const(upload_object_types, do: ["Document", "Image"])

  const(activity_json_canonical_mime_type,
    do: "application/ld+json; profile=\"https://www.w3.org/ns/activitystreams\""
  )

  const(activity_json_mime_types,
    do: [
      "application/ld+json; profile=\"https://www.w3.org/ns/activitystreams\"",
      "application/activity+json"
    ]
  )

  const(public_streams,
    do: ["public", "public:local", "public:media", "public:local:media"]
  )
end
