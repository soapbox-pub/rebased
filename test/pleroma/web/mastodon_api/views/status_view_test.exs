# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.StatusViewTest do
  use Pleroma.DataCase

  alias Pleroma.Activity
  alias Pleroma.Bookmark
  alias Pleroma.Conversation.Participation
  alias Pleroma.HTML
  alias Pleroma.Object
  alias Pleroma.Repo
  alias Pleroma.User
  alias Pleroma.UserRelationship
  alias Pleroma.Web.CommonAPI
  alias Pleroma.Web.MastodonAPI.AccountView
  alias Pleroma.Web.MastodonAPI.StatusView

  require Bitwise

  import Pleroma.Factory
  import Tesla.Mock
  import OpenApiSpex.TestAssertions

  setup do
    mock(fn env -> apply(HttpRequestMock, :request, [env]) end)
    :ok
  end

  test "has an emoji reaction list" do
    user = insert(:user)
    other_user = insert(:user)
    third_user = insert(:user)
    {:ok, activity} = CommonAPI.post(user, %{status: "dae cofe??"})

    {:ok, _} = CommonAPI.react_with_emoji(activity.id, user, "☕")
    {:ok, _} = CommonAPI.react_with_emoji(activity.id, third_user, "🍵")
    {:ok, _} = CommonAPI.react_with_emoji(activity.id, other_user, "☕")
    activity = Repo.get(Activity, activity.id)
    status = StatusView.render("show.json", activity: activity)

    assert_schema(status, "Status", Pleroma.Web.ApiSpec.spec())

    assert status[:pleroma][:emoji_reactions] == [
             %{name: "☕", count: 2, me: false},
             %{name: "🍵", count: 1, me: false}
           ]

    status = StatusView.render("show.json", activity: activity, for: user)

    assert_schema(status, "Status", Pleroma.Web.ApiSpec.spec())

    assert status[:pleroma][:emoji_reactions] == [
             %{name: "☕", count: 2, me: true},
             %{name: "🍵", count: 1, me: false}
           ]
  end

  test "works correctly with badly formatted emojis" do
    user = insert(:user)
    {:ok, activity} = CommonAPI.post(user, %{status: "yo"})

    activity
    |> Object.normalize(fetch: false)
    |> Object.update_data(%{"reactions" => %{"☕" => [user.ap_id], "x" => 1}})

    activity = Activity.get_by_id(activity.id)

    status = StatusView.render("show.json", activity: activity, for: user)

    assert status[:pleroma][:emoji_reactions] == [
             %{name: "☕", count: 1, me: true}
           ]
  end

  test "doesn't show reactions from muted and blocked users" do
    user = insert(:user)
    other_user = insert(:user)
    third_user = insert(:user)

    {:ok, activity} = CommonAPI.post(user, %{status: "dae cofe??"})

    {:ok, _} = User.mute(user, other_user)
    {:ok, _} = User.block(other_user, third_user)

    {:ok, _} = CommonAPI.react_with_emoji(activity.id, other_user, "☕")

    activity = Repo.get(Activity, activity.id)
    status = StatusView.render("show.json", activity: activity)

    assert status[:pleroma][:emoji_reactions] == [
             %{name: "☕", count: 1, me: false}
           ]

    status = StatusView.render("show.json", activity: activity, for: user)

    assert status[:pleroma][:emoji_reactions] == []

    {:ok, _} = CommonAPI.react_with_emoji(activity.id, third_user, "☕")

    status = StatusView.render("show.json", activity: activity)

    assert status[:pleroma][:emoji_reactions] == [
             %{name: "☕", count: 2, me: false}
           ]

    status = StatusView.render("show.json", activity: activity, for: user)

    assert status[:pleroma][:emoji_reactions] == [
             %{name: "☕", count: 1, me: false}
           ]

    status = StatusView.render("show.json", activity: activity, for: other_user)

    assert status[:pleroma][:emoji_reactions] == [
             %{name: "☕", count: 1, me: true}
           ]
  end

  test "loads and returns the direct conversation id when given the `with_direct_conversation_id` option" do
    user = insert(:user)

    {:ok, activity} = CommonAPI.post(user, %{status: "Hey @shp!", visibility: "direct"})
    [participation] = Participation.for_user(user)

    status =
      StatusView.render("show.json",
        activity: activity,
        with_direct_conversation_id: true,
        for: user
      )

    assert status[:pleroma][:direct_conversation_id] == participation.id

    status = StatusView.render("show.json", activity: activity, for: user)
    assert status[:pleroma][:direct_conversation_id] == nil
    assert_schema(status, "Status", Pleroma.Web.ApiSpec.spec())
  end

  test "returns the direct conversation id when given the `direct_conversation_id` option" do
    user = insert(:user)

    {:ok, activity} = CommonAPI.post(user, %{status: "Hey @shp!", visibility: "direct"})
    [participation] = Participation.for_user(user)

    status =
      StatusView.render("show.json",
        activity: activity,
        direct_conversation_id: participation.id,
        for: user
      )

    assert status[:pleroma][:direct_conversation_id] == participation.id
    assert_schema(status, "Status", Pleroma.Web.ApiSpec.spec())
  end

  test "returns a temporary ap_id based user for activities missing db users" do
    user = insert(:user)

    {:ok, activity} = CommonAPI.post(user, %{status: "Hey @shp!", visibility: "direct"})

    Repo.delete(user)
    User.invalidate_cache(user)

    finger_url =
      "https://localhost/.well-known/webfinger?resource=acct:#{user.nickname}@localhost"

    Tesla.Mock.mock_global(fn
      %{method: :get, url: "http://localhost/.well-known/host-meta"} ->
        %Tesla.Env{status: 404, body: ""}

      %{method: :get, url: "https://localhost/.well-known/host-meta"} ->
        %Tesla.Env{status: 404, body: ""}

      %{
        method: :get,
        url: ^finger_url
      } ->
        %Tesla.Env{status: 404, body: ""}
    end)

    %{account: ms_user} = StatusView.render("show.json", activity: activity)

    assert ms_user.acct == "erroruser@example.com"
  end

  test "tries to get a user by nickname if fetching by ap_id doesn't work" do
    user = insert(:user)

    {:ok, activity} = CommonAPI.post(user, %{status: "Hey @shp!", visibility: "direct"})

    {:ok, user} =
      user
      |> Ecto.Changeset.change(%{ap_id: "#{user.ap_id}/extension/#{user.nickname}"})
      |> Repo.update()

    User.invalidate_cache(user)

    result = StatusView.render("show.json", activity: activity)

    assert result[:account][:id] == to_string(user.id)
    assert_schema(result, "Status", Pleroma.Web.ApiSpec.spec())
  end

  test "a note with null content" do
    note = insert(:note_activity)
    note_object = Object.normalize(note, fetch: false)

    data =
      note_object.data
      |> Map.put("content", nil)

    Object.change(note_object, %{data: data})
    |> Object.update_and_set_cache()

    User.get_cached_by_ap_id(note.data["actor"])

    status = StatusView.render("show.json", %{activity: note})

    assert status.content == ""
    assert_schema(status, "Status", Pleroma.Web.ApiSpec.spec())
  end

  test "a note activity" do
    note = insert(:note_activity)
    object_data = Object.normalize(note, fetch: false).data
    user = User.get_cached_by_ap_id(note.data["actor"])

    convo_id = :erlang.crc32(object_data["context"]) |> Bitwise.band(Bitwise.bnot(0x8000_0000))

    status = StatusView.render("show.json", %{activity: note})

    created_at =
      (object_data["published"] || "")
      |> String.replace(~r/\.\d+Z/, ".000Z")

    expected = %{
      id: to_string(note.id),
      uri: object_data["id"],
      url: Pleroma.Web.Router.Helpers.o_status_url(Pleroma.Web.Endpoint, :notice, note),
      account: AccountView.render("show.json", %{user: user, skip_visibility_check: true}),
      in_reply_to_id: nil,
      in_reply_to_account_id: nil,
      card: nil,
      reblog: nil,
      content: HTML.filter_tags(object_data["content"]),
      text: nil,
      created_at: created_at,
      edited_at: nil,
      reblogs_count: 0,
      replies_count: 0,
      favourites_count: 0,
      reblogged: false,
      bookmarked: false,
      favourited: false,
      muted: false,
      pinned: false,
      sensitive: false,
      poll: nil,
      spoiler_text: HTML.filter_tags(object_data["summary"]),
      visibility: "public",
      media_attachments: [],
      mentions: [],
      tags: [
        %{
          name: "#{hd(object_data["tag"])}",
          url: "http://localhost:4001/tag/#{hd(object_data["tag"])}"
        }
      ],
      application: nil,
      language: nil,
      emojis: [
        %{
          shortcode: "2hu",
          url: "corndog.png",
          static_url: "corndog.png",
          visible_in_picker: false
        }
      ],
      pleroma: %{
        local: true,
        conversation_id: convo_id,
        context: object_data["context"],
        in_reply_to_account_acct: nil,
        content: %{"text/plain" => HTML.strip_tags(object_data["content"])},
        spoiler_text: %{"text/plain" => HTML.strip_tags(object_data["summary"])},
        expires_at: nil,
        direct_conversation_id: nil,
        thread_muted: false,
        emoji_reactions: [],
        parent_visible: false,
        pinned_at: nil
      }
    }

    assert status == expected
    assert_schema(status, "Status", Pleroma.Web.ApiSpec.spec())
  end

  test "tells if the message is muted for some reason" do
    user = insert(:user)
    other_user = insert(:user)

    {:ok, _user_relationships} = User.mute(user, other_user)

    {:ok, activity} = CommonAPI.post(other_user, %{status: "test"})

    relationships_opt = UserRelationship.view_relationships_option(user, [other_user])

    opts = %{activity: activity}
    status = StatusView.render("show.json", opts)
    assert status.muted == false
    assert_schema(status, "Status", Pleroma.Web.ApiSpec.spec())

    status = StatusView.render("show.json", Map.put(opts, :relationships, relationships_opt))
    assert status.muted == false

    for_opts = %{activity: activity, for: user}
    status = StatusView.render("show.json", for_opts)
    assert status.muted == true

    status = StatusView.render("show.json", Map.put(for_opts, :relationships, relationships_opt))
    assert status.muted == true
    assert_schema(status, "Status", Pleroma.Web.ApiSpec.spec())
  end

  test "tells if the message is thread muted" do
    user = insert(:user)
    other_user = insert(:user)

    {:ok, _user_relationships} = User.mute(user, other_user)

    {:ok, activity} = CommonAPI.post(other_user, %{status: "test"})
    status = StatusView.render("show.json", %{activity: activity, for: user})

    assert status.pleroma.thread_muted == false

    {:ok, activity} = CommonAPI.add_mute(user, activity)

    status = StatusView.render("show.json", %{activity: activity, for: user})

    assert status.pleroma.thread_muted == true
  end

  test "tells if the status is bookmarked" do
    user = insert(:user)

    {:ok, activity} = CommonAPI.post(user, %{status: "Cute girls doing cute things"})
    status = StatusView.render("show.json", %{activity: activity})

    assert status.bookmarked == false

    status = StatusView.render("show.json", %{activity: activity, for: user})

    assert status.bookmarked == false

    {:ok, _bookmark} = Bookmark.create(user.id, activity.id)

    activity = Activity.get_by_id_with_object(activity.id)

    status = StatusView.render("show.json", %{activity: activity, for: user})

    assert status.bookmarked == true
  end

  test "a reply" do
    note = insert(:note_activity)
    user = insert(:user)

    {:ok, activity} = CommonAPI.post(user, %{status: "he", in_reply_to_status_id: note.id})

    status = StatusView.render("show.json", %{activity: activity})

    assert status.in_reply_to_id == to_string(note.id)

    [status] = StatusView.render("index.json", %{activities: [activity], as: :activity})

    assert status.in_reply_to_id == to_string(note.id)
  end

  test "contains mentions" do
    user = insert(:user)
    mentioned = insert(:user)

    {:ok, activity} = CommonAPI.post(user, %{status: "hi @#{mentioned.nickname}"})

    status = StatusView.render("show.json", %{activity: activity})

    assert status.mentions ==
             Enum.map([mentioned], fn u -> AccountView.render("mention.json", %{user: u}) end)

    assert_schema(status, "Status", Pleroma.Web.ApiSpec.spec())
  end

  test "create mentions from the 'to' field" do
    %User{ap_id: recipient_ap_id} = insert(:user)
    cc = insert_pair(:user) |> Enum.map(& &1.ap_id)

    object =
      insert(:note, %{
        data: %{
          "to" => [recipient_ap_id],
          "cc" => cc
        }
      })

    activity =
      insert(:note_activity, %{
        note: object,
        recipients: [recipient_ap_id | cc]
      })

    assert length(activity.recipients) == 3

    %{mentions: [mention] = mentions} = StatusView.render("show.json", %{activity: activity})

    assert length(mentions) == 1
    assert mention.url == recipient_ap_id
  end

  test "create mentions from the 'tag' field" do
    recipient = insert(:user)
    cc = insert_pair(:user) |> Enum.map(& &1.ap_id)

    object =
      insert(:note, %{
        data: %{
          "cc" => cc,
          "tag" => [
            %{
              "href" => recipient.ap_id,
              "name" => recipient.nickname,
              "type" => "Mention"
            },
            %{
              "href" => "https://example.com/search?tag=test",
              "name" => "#test",
              "type" => "Hashtag"
            }
          ]
        }
      })

    activity =
      insert(:note_activity, %{
        note: object,
        recipients: [recipient.ap_id | cc]
      })

    assert length(activity.recipients) == 3

    %{mentions: [mention] = mentions} = StatusView.render("show.json", %{activity: activity})

    assert length(mentions) == 1
    assert mention.url == recipient.ap_id
  end

  test "attachments" do
    object = %{
      "type" => "Image",
      "url" => [
        %{
          "mediaType" => "image/png",
          "href" => "someurl",
          "width" => 200,
          "height" => 100
        }
      ],
      "blurhash" => "UJJ8X[xYW,%Jtq%NNFbXB5j]IVM|9GV=WHRn",
      "uuid" => 6
    }

    expected = %{
      id: "1638338801",
      type: "image",
      url: "someurl",
      remote_url: "someurl",
      preview_url: "someurl",
      text_url: "someurl",
      description: nil,
      pleroma: %{mime_type: "image/png"},
      meta: %{original: %{width: 200, height: 100, aspect: 2}},
      blurhash: "UJJ8X[xYW,%Jtq%NNFbXB5j]IVM|9GV=WHRn"
    }

    api_spec = Pleroma.Web.ApiSpec.spec()

    assert expected == StatusView.render("attachment.json", %{attachment: object})
    assert_schema(expected, "Attachment", api_spec)

    # If theres a "id", use that instead of the generated one
    object = Map.put(object, "id", 2)
    result = StatusView.render("attachment.json", %{attachment: object})

    assert %{id: "2"} = result
    assert_schema(result, "Attachment", api_spec)
  end

  test "put the url advertised in the Activity in to the url attribute" do
    id = "https://wedistribute.org/wp-json/pterotype/v1/object/85810"
    [activity] = Activity.search(nil, id)

    status = StatusView.render("show.json", %{activity: activity})

    assert status.uri == id
    assert status.url == "https://wedistribute.org/2019/07/mastodon-drops-ostatus/"
  end

  test "a reblog" do
    user = insert(:user)
    activity = insert(:note_activity)

    {:ok, reblog} = CommonAPI.repeat(activity.id, user)

    represented = StatusView.render("show.json", %{for: user, activity: reblog})

    assert represented[:id] == to_string(reblog.id)
    assert represented[:reblog][:id] == to_string(activity.id)
    assert represented[:emojis] == []
    assert_schema(represented, "Status", Pleroma.Web.ApiSpec.spec())
  end

  test "a peertube video" do
    user = insert(:user)

    {:ok, object} =
      Pleroma.Object.Fetcher.fetch_object_from_id(
        "https://peertube.moe/videos/watch/df5f464b-be8d-46fb-ad81-2d4c2d1630e3"
      )

    %Activity{} = activity = Activity.get_create_by_object_ap_id(object.data["id"])

    represented = StatusView.render("show.json", %{for: user, activity: activity})

    assert represented[:id] == to_string(activity.id)
    assert length(represented[:media_attachments]) == 1
    assert_schema(represented, "Status", Pleroma.Web.ApiSpec.spec())
  end

  test "funkwhale audio" do
    user = insert(:user)

    {:ok, object} =
      Pleroma.Object.Fetcher.fetch_object_from_id(
        "https://channels.tests.funkwhale.audio/federation/music/uploads/42342395-0208-4fee-a38d-259a6dae0871"
      )

    %Activity{} = activity = Activity.get_create_by_object_ap_id(object.data["id"])

    represented = StatusView.render("show.json", %{for: user, activity: activity})

    assert represented[:id] == to_string(activity.id)
    assert length(represented[:media_attachments]) == 1
  end

  test "a Mobilizon event" do
    user = insert(:user)

    {:ok, object} =
      Pleroma.Object.Fetcher.fetch_object_from_id(
        "https://mobilizon.org/events/252d5816-00a3-4a89-a66f-15bf65c33e39"
      )

    %Activity{} = activity = Activity.get_create_by_object_ap_id(object.data["id"])

    represented = StatusView.render("show.json", %{for: user, activity: activity})

    assert represented[:id] == to_string(activity.id)

    assert represented[:url] ==
             "https://mobilizon.org/events/252d5816-00a3-4a89-a66f-15bf65c33e39"

    assert represented[:content] ==
             "<p><a href=\"https://mobilizon.org/events/252d5816-00a3-4a89-a66f-15bf65c33e39\">Mobilizon Launching Party</a></p><p>Mobilizon is now federated! 🎉</p><p></p><p>You can view this event from other instances if they are subscribed to mobilizon.org, and soon directly from Mastodon and Pleroma. It is possible that you may see some comments from other instances, including Mastodon ones, just below.</p><p></p><p>With a Mobilizon account on an instance, you may <strong>participate</strong> at events from other instances and <strong>add comments</strong> on events.</p><p></p><p>Of course, it&#39;s still <u>a work in progress</u>: if reports made from an instance on events and comments can be federated, you can&#39;t block people right now, and moderators actions are rather limited, but this <strong>will definitely get fixed over time</strong> until first stable version next year.</p><p></p><p>Anyway, if you want to come up with some feedback, head over to our forum or - if you feel you have technical skills and are familiar with it - on our Gitlab repository.</p><p></p><p>Also, to people that want to set Mobilizon themselves even though we really don&#39;t advise to do that for now, we have a little documentation but it&#39;s quite the early days and you&#39;ll probably need some help. No worries, you can chat with us on our Forum or though our Matrix channel.</p><p></p><p>Check our website for more informations and follow us on Twitter or Mastodon.</p>"
  end

  describe "build_tags/1" do
    test "it returns a a dictionary tags" do
      object_tags = [
        "fediverse",
        "mastodon",
        "nextcloud",
        %{
          "href" => "https://kawen.space/users/lain",
          "name" => "@lain@kawen.space",
          "type" => "Mention"
        }
      ]

      assert StatusView.build_tags(object_tags) == [
               %{name: "fediverse", url: "http://localhost:4001/tag/fediverse"},
               %{name: "mastodon", url: "http://localhost:4001/tag/mastodon"},
               %{name: "nextcloud", url: "http://localhost:4001/tag/nextcloud"}
             ]
    end
  end

  describe "rich media cards" do
    test "a rich media card without a site name renders correctly" do
      page_url = "http://example.com"

      card = %{
        url: page_url,
        image: page_url <> "/example.jpg",
        title: "Example website"
      }

      %{provider_name: "example.com"} =
        StatusView.render("card.json", %{page_url: page_url, rich_media: card})
    end

    test "a rich media card without a site name or image renders correctly" do
      page_url = "http://example.com"

      card = %{
        url: page_url,
        title: "Example website"
      }

      %{provider_name: "example.com"} =
        StatusView.render("card.json", %{page_url: page_url, rich_media: card})
    end

    test "a rich media card without an image renders correctly" do
      page_url = "http://example.com"

      card = %{
        url: page_url,
        site_name: "Example site name",
        title: "Example website"
      }

      %{provider_name: "example.com"} =
        StatusView.render("card.json", %{page_url: page_url, rich_media: card})
    end

    test "a rich media card with all relevant data renders correctly" do
      page_url = "http://example.com"

      card = %{
        url: page_url,
        site_name: "Example site name",
        title: "Example website",
        image: page_url <> "/example.jpg",
        description: "Example description"
      }

      %{provider_name: "example.com"} =
        StatusView.render("card.json", %{page_url: page_url, rich_media: card})
    end
  end

  test "does not embed a relationship in the account" do
    user = insert(:user)
    other_user = insert(:user)

    {:ok, activity} =
      CommonAPI.post(user, %{
        status: "drink more water"
      })

    result = StatusView.render("show.json", %{activity: activity, for: other_user})

    assert result[:account][:pleroma][:relationship] == %{}
    assert_schema(result, "Status", Pleroma.Web.ApiSpec.spec())
  end

  test "does not embed a relationship in the account in reposts" do
    user = insert(:user)
    other_user = insert(:user)

    {:ok, activity} =
      CommonAPI.post(user, %{
        status: "˙˙ɐʎns"
      })

    {:ok, activity} = CommonAPI.repeat(activity.id, other_user)

    result = StatusView.render("show.json", %{activity: activity, for: user})

    assert result[:account][:pleroma][:relationship] == %{}
    assert result[:reblog][:account][:pleroma][:relationship] == %{}
    assert_schema(result, "Status", Pleroma.Web.ApiSpec.spec())
  end

  test "visibility/list" do
    user = insert(:user)

    {:ok, list} = Pleroma.List.create("foo", user)

    {:ok, activity} = CommonAPI.post(user, %{status: "foobar", visibility: "list:#{list.id}"})

    status = StatusView.render("show.json", activity: activity)

    assert status.visibility == "list"
  end

  test "has a field for parent visibility" do
    user = insert(:user)
    poster = insert(:user)

    {:ok, invisible} = CommonAPI.post(poster, %{status: "hey", visibility: "private"})

    {:ok, visible} =
      CommonAPI.post(poster, %{status: "hey", visibility: "private", in_reply_to_id: invisible.id})

    status = StatusView.render("show.json", activity: visible, for: user)
    refute status.pleroma.parent_visible

    status = StatusView.render("show.json", activity: visible, for: poster)
    assert status.pleroma.parent_visible
  end

  test "it shows edited_at" do
    poster = insert(:user)

    {:ok, post} = CommonAPI.post(poster, %{status: "hey"})

    status = StatusView.render("show.json", activity: post)
    refute status.edited_at

    {:ok, _} = CommonAPI.update(poster, post, %{status: "mew mew"})
    edited = Pleroma.Activity.normalize(post)

    status = StatusView.render("show.json", activity: edited)
    assert status.edited_at
  end

  test "with a source object" do
    note =
      insert(:note,
        data: %{"source" => %{"content" => "object source", "mediaType" => "text/markdown"}}
      )

    activity = insert(:note_activity, note: note)

    status = StatusView.render("show.json", activity: activity, with_source: true)
    assert status.text == "object source"
  end

  describe "source.json" do
    test "with a source object, renders both source and content type" do
      note =
        insert(:note,
          data: %{"source" => %{"content" => "object source", "mediaType" => "text/markdown"}}
        )

      activity = insert(:note_activity, note: note)

      status = StatusView.render("source.json", activity: activity)
      assert status.text == "object source"
      assert status.content_type == "text/markdown"
    end

    test "with a source string, renders source and put text/plain as the content type" do
      note = insert(:note, data: %{"source" => "string source"})
      activity = insert(:note_activity, note: note)

      status = StatusView.render("source.json", activity: activity)
      assert status.text == "string source"
      assert status.content_type == "text/plain"
    end
  end
end
