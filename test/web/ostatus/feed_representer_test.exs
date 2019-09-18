# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.OStatus.FeedRepresenterTest do
  use Pleroma.DataCase
  import Pleroma.Factory
  alias Pleroma.User
  alias Pleroma.Web.OStatus
  alias Pleroma.Web.OStatus.ActivityRepresenter
  alias Pleroma.Web.OStatus.FeedRepresenter
  alias Pleroma.Web.OStatus.UserRepresenter

  test "returns a feed of the last 20 items of the user" do
    note_activity = insert(:note_activity)
    user = User.get_cached_by_ap_id(note_activity.data["actor"])

    tuple = FeedRepresenter.to_simple_form(user, [note_activity], [user])

    most_recent_update =
      note_activity.updated_at
      |> NaiveDateTime.to_iso8601()

    res = :xmerl.export_simple_content(tuple, :xmerl_xml) |> to_string

    user_xml =
      UserRepresenter.to_simple_form(user)
      |> :xmerl.export_simple_content(:xmerl_xml)

    entry_xml =
      ActivityRepresenter.to_simple_form(note_activity, user)
      |> :xmerl.export_simple_content(:xmerl_xml)

    expected = """
    <feed xmlns="http://www.w3.org/2005/Atom" xmlns:thr="http://purl.org/syndication/thread/1.0" xmlns:activity="http://activitystrea.ms/spec/1.0/" xmlns:poco="http://portablecontacts.net/spec/1.0" xmlns:ostatus="http://ostatus.org/schema/1.0">
      <id>#{OStatus.feed_path(user)}</id>
      <title>#{user.nickname}'s timeline</title>
      <updated>#{most_recent_update}</updated>
      <logo>#{User.avatar_url(user)}</logo>
      <link rel="hub" href="#{OStatus.pubsub_path(user)}" />
      <link rel="salmon" href="#{OStatus.salmon_path(user)}" />
      <link rel="self" href="#{OStatus.feed_path(user)}" type="application/atom+xml" />
      <author>
        #{user_xml}
      </author>
      <link rel="next" href="#{OStatus.feed_path(user)}?max_id=#{note_activity.id}" type="application/atom+xml" />
      <entry>
        #{entry_xml}
      </entry>
    </feed>
    """

    assert clean(res) == clean(expected)
  end

  defp clean(string) do
    String.replace(string, ~r/\s/, "")
  end
end
