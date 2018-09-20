defmodule Pleroma.Web.MastodonAPI.StatusViewTest do
  use Pleroma.DataCase

  alias Pleroma.Web.MastodonAPI.{StatusView, AccountView}
  alias Pleroma.User
  alias Pleroma.Web.OStatus
  alias Pleroma.Web.CommonAPI
  import Pleroma.Factory

  test "a note activity" do
    note = insert(:note_activity)
    user = User.get_cached_by_ap_id(note.data["actor"])

    status = StatusView.render("status.json", %{activity: note})

    created_at =
      (note.data["object"]["published"] || "")
      |> String.replace(~r/\.\d+Z/, ".000Z")

    expected = %{
      id: to_string(note.id),
      uri: note.data["object"]["id"],
      url: note.data["object"]["id"],
      account: AccountView.render("account.json", %{user: user}),
      in_reply_to_id: nil,
      in_reply_to_account_id: nil,
      reblog: nil,
      content: HtmlSanitizeEx.basic_html(note.data["object"]["content"]),
      created_at: created_at,
      reblogs_count: 0,
      replies_count: 0,
      favourites_count: 0,
      reblogged: false,
      favourited: false,
      muted: false,
      sensitive: false,
      spoiler_text: note.data["object"]["summary"],
      visibility: "public",
      media_attachments: [],
      mentions: [],
      tags: [],
      application: %{
        name: "Web",
        website: nil
      },
      language: nil,
      emojis: [
        %{
          shortcode: "2hu",
          url: "corndog.png",
          static_url: "corndog.png",
          visible_in_picker: false
        }
      ]
    }

    assert status == expected
  end

  test "a reply" do
    note = insert(:note_activity)
    user = insert(:user)

    {:ok, activity} =
      CommonAPI.post(user, %{"status" => "he", "in_reply_to_status_id" => note.id})

    status = StatusView.render("status.json", %{activity: activity})

    assert status.in_reply_to_id == to_string(note.id)

    [status] = StatusView.render("index.json", %{activities: [activity], as: :activity})

    assert status.in_reply_to_id == to_string(note.id)
  end

  test "contains mentions" do
    incoming = File.read!("test/fixtures/incoming_reply_mastodon.xml")
    # a user with this ap id might be in the cache.
    recipient = "https://pleroma.soykaf.com/users/lain"
    user = insert(:user, %{ap_id: recipient})

    {:ok, [activity]} = OStatus.handle_incoming(incoming)

    status = StatusView.render("status.json", %{activity: activity})

    assert status.mentions == [AccountView.render("mention.json", %{user: user})]
  end

  test "attachments" do
    object = %{
      "type" => "Image",
      "url" => [
        %{
          "mediaType" => "image/png",
          "href" => "someurl"
        }
      ],
      "uuid" => 6
    }

    expected = %{
      id: "1638338801",
      type: "image",
      url: "someurl",
      remote_url: "someurl",
      preview_url: "someurl",
      text_url: "someurl",
      description: nil
    }

    assert expected == StatusView.render("attachment.json", %{attachment: object})

    # If theres a "id", use that instead of the generated one
    object = Map.put(object, "id", 2)
    assert %{id: "2"} = StatusView.render("attachment.json", %{attachment: object})
  end

  test "a reblog" do
    user = insert(:user)
    activity = insert(:note_activity)

    {:ok, reblog, _} = CommonAPI.repeat(activity.id, user)

    represented = StatusView.render("status.json", %{for: user, activity: reblog})

    assert represented[:id] == to_string(reblog.id)
    assert represented[:reblog][:id] == to_string(activity.id)
    assert represented[:emojis] == []
  end
end
