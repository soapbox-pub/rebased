# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.CommonAPITest do
  use Oban.Testing, repo: Pleroma.Repo
  use Pleroma.DataCase

  alias Pleroma.Activity
  alias Pleroma.Chat
  alias Pleroma.Conversation.Participation
  alias Pleroma.Notification
  alias Pleroma.Object
  alias Pleroma.Repo
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Pleroma.Web.ActivityPub.Transmogrifier
  alias Pleroma.Web.ActivityPub.Visibility
  alias Pleroma.Web.AdminAPI.AccountView
  alias Pleroma.Web.CommonAPI
  alias Pleroma.Workers.PollWorker

  import Pleroma.Factory
  import Mock
  import Ecto.Query, only: [from: 2]

  require Pleroma.Constants

  setup_all do
    Tesla.Mock.mock_global(fn env -> apply(HttpRequestMock, :request, [env]) end)
    :ok
  end

  setup do: clear_config([:instance, :safe_dm_mentions])
  setup do: clear_config([:instance, :limit])
  setup do: clear_config([:instance, :max_pinned_statuses])

  describe "posting polls" do
    test "it posts a poll" do
      user = insert(:user)

      {:ok, activity} =
        CommonAPI.post(user, %{
          status: "who is the best",
          poll: %{expires_in: 600, options: ["reimu", "marisa"]}
        })

      object = Object.normalize(activity, fetch: false)

      assert object.data["type"] == "Question"
      assert object.data["oneOf"] |> length() == 2

      assert_enqueued(
        worker: PollWorker,
        args: %{op: "poll_end", activity_id: activity.id},
        scheduled_at: NaiveDateTime.from_iso8601!(object.data["closed"])
      )
    end
  end

  describe "blocking" do
    setup do
      blocker = insert(:user)
      blocked = insert(:user)
      User.follow(blocker, blocked)
      User.follow(blocked, blocker)
      %{blocker: blocker, blocked: blocked}
    end

    test "it blocks and federates", %{blocker: blocker, blocked: blocked} do
      clear_config([:instance, :federating], true)

      with_mock Pleroma.Web.Federator,
        publish: fn _ -> nil end do
        assert {:ok, block} = CommonAPI.block(blocker, blocked)

        assert block.local
        assert User.blocks?(blocker, blocked)
        refute User.following?(blocker, blocked)
        refute User.following?(blocked, blocker)

        assert called(Pleroma.Web.Federator.publish(block))
      end
    end

    test "it blocks and does not federate if outgoing blocks are disabled", %{
      blocker: blocker,
      blocked: blocked
    } do
      clear_config([:instance, :federating], true)
      clear_config([:activitypub, :outgoing_blocks], false)

      with_mock Pleroma.Web.Federator,
        publish: fn _ -> nil end do
        assert {:ok, block} = CommonAPI.block(blocker, blocked)

        assert block.local
        assert User.blocks?(blocker, blocked)
        refute User.following?(blocker, blocked)
        refute User.following?(blocked, blocker)

        refute called(Pleroma.Web.Federator.publish(block))
      end
    end
  end

  describe "posting chat messages" do
    setup do: clear_config([:instance, :chat_limit])

    test "it posts a self-chat" do
      author = insert(:user)
      recipient = author

      {:ok, activity} =
        CommonAPI.post_chat_message(
          author,
          recipient,
          "remember to buy milk when milk truk arive"
        )

      assert activity.data["type"] == "Create"
    end

    test "it posts a chat message without content but with an attachment" do
      author = insert(:user)
      recipient = insert(:user)

      file = %Plug.Upload{
        content_type: "image/jpeg",
        path: Path.absname("test/fixtures/image.jpg"),
        filename: "an_image.jpg"
      }

      {:ok, upload} = ActivityPub.upload(file, actor: author.ap_id)

      with_mocks([
        {
          Pleroma.Web.Streamer,
          [],
          [
            stream: fn _, _ ->
              nil
            end
          ]
        },
        {
          Pleroma.Web.Push,
          [],
          [
            send: fn _ -> nil end
          ]
        }
      ]) do
        {:ok, activity} =
          CommonAPI.post_chat_message(
            author,
            recipient,
            nil,
            media_id: upload.id
          )

        notification =
          Notification.for_user_and_activity(recipient, activity)
          |> Repo.preload(:activity)

        assert called(Pleroma.Web.Push.send(notification))
        assert called(Pleroma.Web.Streamer.stream(["user", "user:notification"], notification))
        assert called(Pleroma.Web.Streamer.stream(["user", "user:pleroma_chat"], :_))

        assert activity
      end
    end

    test "it adds html newlines" do
      author = insert(:user)
      recipient = insert(:user)

      other_user = insert(:user)

      {:ok, activity} =
        CommonAPI.post_chat_message(
          author,
          recipient,
          "uguu\nuguuu"
        )

      assert other_user.ap_id not in activity.recipients

      object = Object.normalize(activity, fetch: false)

      assert object.data["content"] == "uguu<br/>uguuu"
    end

    test "it linkifies" do
      author = insert(:user)
      recipient = insert(:user)

      other_user = insert(:user)

      {:ok, activity} =
        CommonAPI.post_chat_message(
          author,
          recipient,
          "https://example.org is the site of @#{other_user.nickname} #2hu"
        )

      assert other_user.ap_id not in activity.recipients

      object = Object.normalize(activity, fetch: false)

      assert object.data["content"] ==
               "<a href=\"https://example.org\" rel=\"ugc\">https://example.org</a> is the site of <span class=\"h-card\"><a class=\"u-url mention\" data-user=\"#{other_user.id}\" href=\"#{other_user.ap_id}\" rel=\"ugc\">@<span>#{other_user.nickname}</span></a></span> <a class=\"hashtag\" data-tag=\"2hu\" href=\"http://localhost:4001/tag/2hu\">#2hu</a>"
    end

    test "it posts a chat message" do
      author = insert(:user)
      recipient = insert(:user)

      {:ok, activity} =
        CommonAPI.post_chat_message(
          author,
          recipient,
          "a test message <script>alert('uuu')</script> :firefox:"
        )

      assert activity.data["type"] == "Create"
      assert activity.local
      object = Object.normalize(activity, fetch: false)

      assert object.data["type"] == "ChatMessage"
      assert object.data["to"] == [recipient.ap_id]

      assert object.data["content"] ==
               "a test message &lt;script&gt;alert(&#39;uuu&#39;)&lt;/script&gt; :firefox:"

      assert object.data["emoji"] == %{
               "firefox" => "http://localhost:4001/emoji/Firefox.gif"
             }

      assert Chat.get(author.id, recipient.ap_id)
      assert Chat.get(recipient.id, author.ap_id)

      assert :ok == Pleroma.Web.Federator.perform(:publish, activity)
    end

    test "it reject messages over the local limit" do
      clear_config([:instance, :chat_limit], 2)

      author = insert(:user)
      recipient = insert(:user)

      {:error, message} =
        CommonAPI.post_chat_message(
          author,
          recipient,
          "123"
        )

      assert message == :content_too_long
    end

    test "it reject messages via MRF" do
      clear_config([:mrf_keyword, :reject], ["GNO"])
      clear_config([:mrf, :policies], [Pleroma.Web.ActivityPub.MRF.KeywordPolicy])

      author = insert(:user)
      recipient = insert(:user)

      assert {:reject, "[KeywordPolicy] Matches with rejected keyword"} ==
               CommonAPI.post_chat_message(author, recipient, "GNO/Linux")
    end
  end

  describe "unblocking" do
    test "it works even without an existing block activity" do
      blocked = insert(:user)
      blocker = insert(:user)
      User.block(blocker, blocked)

      assert User.blocks?(blocker, blocked)
      assert {:ok, :no_activity} == CommonAPI.unblock(blocker, blocked)
      refute User.blocks?(blocker, blocked)
    end
  end

  describe "deletion" do
    test "it works with pruned objects" do
      user = insert(:user)

      {:ok, post} = CommonAPI.post(user, %{status: "namu amida butsu"})

      clear_config([:instance, :federating], true)

      Object.normalize(post, fetch: false)
      |> Object.prune()

      with_mock Pleroma.Web.Federator,
        publish: fn _ -> nil end do
        assert {:ok, delete} = CommonAPI.delete(post.id, user)
        assert delete.local
        assert called(Pleroma.Web.Federator.publish(delete))
      end

      refute Activity.get_by_id(post.id)
    end

    test "it allows users to delete their posts" do
      user = insert(:user)

      {:ok, post} = CommonAPI.post(user, %{status: "namu amida butsu"})

      clear_config([:instance, :federating], true)

      with_mock Pleroma.Web.Federator,
        publish: fn _ -> nil end do
        assert {:ok, delete} = CommonAPI.delete(post.id, user)
        assert delete.local
        assert called(Pleroma.Web.Federator.publish(delete))
      end

      refute Activity.get_by_id(post.id)
    end

    test "it does not allow a user to delete their posts" do
      user = insert(:user)
      other_user = insert(:user)

      {:ok, post} = CommonAPI.post(user, %{status: "namu amida butsu"})

      assert {:error, "Could not delete"} = CommonAPI.delete(post.id, other_user)
      assert Activity.get_by_id(post.id)
    end

    test "it allows moderators to delete other user's posts" do
      user = insert(:user)
      moderator = insert(:user, is_moderator: true)

      {:ok, post} = CommonAPI.post(user, %{status: "namu amida butsu"})

      assert {:ok, delete} = CommonAPI.delete(post.id, moderator)
      assert delete.local

      refute Activity.get_by_id(post.id)
    end

    test "it allows admins to delete other user's posts" do
      user = insert(:user)
      moderator = insert(:user, is_admin: true)

      {:ok, post} = CommonAPI.post(user, %{status: "namu amida butsu"})

      assert {:ok, delete} = CommonAPI.delete(post.id, moderator)
      assert delete.local

      refute Activity.get_by_id(post.id)
    end

    test "superusers deleting non-local posts won't federate the delete" do
      # This is the user of the ingested activity
      _user =
        insert(:user,
          local: false,
          ap_id: "http://mastodon.example.org/users/admin",
          last_refreshed_at: NaiveDateTime.utc_now()
        )

      moderator = insert(:user, is_admin: true)

      data =
        File.read!("test/fixtures/mastodon-post-activity.json")
        |> Jason.decode!()

      {:ok, post} = Transmogrifier.handle_incoming(data)

      with_mock Pleroma.Web.Federator,
        publish: fn _ -> nil end do
        assert {:ok, delete} = CommonAPI.delete(post.id, moderator)
        assert delete.local
        refute called(Pleroma.Web.Federator.publish(:_))
      end

      refute Activity.get_by_id(post.id)
    end
  end

  test "favoriting race condition" do
    user = insert(:user)
    users_serial = insert_list(10, :user)
    users = insert_list(10, :user)

    {:ok, activity} = CommonAPI.post(user, %{status: "."})

    users_serial
    |> Enum.map(fn user ->
      CommonAPI.favorite(user, activity.id)
    end)

    object = Object.get_by_ap_id(activity.data["object"])
    assert object.data["like_count"] == 10

    users
    |> Enum.map(fn user ->
      Task.async(fn ->
        CommonAPI.favorite(user, activity.id)
      end)
    end)
    |> Enum.map(&Task.await/1)

    object = Object.get_by_ap_id(activity.data["object"])
    assert object.data["like_count"] == 20
  end

  test "repeating race condition" do
    user = insert(:user)
    users_serial = insert_list(10, :user)
    users = insert_list(10, :user)

    {:ok, activity} = CommonAPI.post(user, %{status: "."})

    users_serial
    |> Enum.map(fn user ->
      CommonAPI.repeat(activity.id, user)
    end)

    object = Object.get_by_ap_id(activity.data["object"])
    assert object.data["announcement_count"] == 10

    users
    |> Enum.map(fn user ->
      Task.async(fn ->
        CommonAPI.repeat(activity.id, user)
      end)
    end)
    |> Enum.map(&Task.await/1)

    object = Object.get_by_ap_id(activity.data["object"])
    assert object.data["announcement_count"] == 20
  end

  test "when replying to a conversation / participation, it will set the correct context id even if no explicit reply_to is given" do
    user = insert(:user)
    {:ok, activity} = CommonAPI.post(user, %{status: ".", visibility: "direct"})

    [participation] = Participation.for_user(user)

    {:ok, convo_reply} =
      CommonAPI.post(user, %{status: ".", in_reply_to_conversation_id: participation.id})

    assert Visibility.is_direct?(convo_reply)

    assert activity.data["context"] == convo_reply.data["context"]
  end

  test "when replying to a conversation / participation, it only mentions the recipients explicitly declared in the participation" do
    har = insert(:user)
    jafnhar = insert(:user)
    tridi = insert(:user)

    {:ok, activity} =
      CommonAPI.post(har, %{
        status: "@#{jafnhar.nickname} hey",
        visibility: "direct"
      })

    assert har.ap_id in activity.recipients
    assert jafnhar.ap_id in activity.recipients

    [participation] = Participation.for_user(har)

    {:ok, activity} =
      CommonAPI.post(har, %{
        status: "I don't really like @#{tridi.nickname}",
        visibility: "direct",
        in_reply_to_status_id: activity.id,
        in_reply_to_conversation_id: participation.id
      })

    assert har.ap_id in activity.recipients
    assert jafnhar.ap_id in activity.recipients
    refute tridi.ap_id in activity.recipients
  end

  test "with the safe_dm_mention option set, it does not mention people beyond the initial tags" do
    har = insert(:user)
    jafnhar = insert(:user)
    tridi = insert(:user)

    clear_config([:instance, :safe_dm_mentions], true)

    {:ok, activity} =
      CommonAPI.post(har, %{
        status: "@#{jafnhar.nickname} hey, i never want to see @#{tridi.nickname} again",
        visibility: "direct"
      })

    refute tridi.ap_id in activity.recipients
    assert jafnhar.ap_id in activity.recipients
  end

  test "it de-duplicates tags" do
    user = insert(:user)
    {:ok, activity} = CommonAPI.post(user, %{status: "#2hu #2HU"})

    object = Object.normalize(activity, fetch: false)

    assert Object.tags(object) == ["2hu"]
  end

  test "it adds emoji in the object" do
    user = insert(:user)
    {:ok, activity} = CommonAPI.post(user, %{status: ":firefox:"})

    assert Object.normalize(activity, fetch: false).data["emoji"]["firefox"]
  end

  describe "posting" do
    test "it adds an emoji on an external site" do
      user = insert(:user)
      {:ok, activity} = CommonAPI.post(user, %{status: "hey :external_emoji:"})

      assert %{"external_emoji" => url} = Object.normalize(activity).data["emoji"]
      assert url == "https://example.com/emoji.png"

      {:ok, activity} = CommonAPI.post(user, %{status: "hey :blank:"})

      assert %{"blank" => url} = Object.normalize(activity).data["emoji"]
      assert url == "#{Pleroma.Web.Endpoint.url()}/emoji/blank.png"
    end

    test "it copies emoji from the subject of the parent post" do
      %Object{} =
        object =
        Object.normalize("https://patch.cx/objects/a399c28e-c821-4820-bc3e-4afeb044c16f",
          fetch: true
        )

      activity = Activity.get_create_by_object_ap_id(object.data["id"])
      user = insert(:user)

      {:ok, reply_activity} =
        CommonAPI.post(user, %{
          in_reply_to_id: activity.id,
          status: ":joker_disapprove:",
          spoiler_text: ":joker_smile:"
        })

      assert Object.normalize(reply_activity).data["emoji"]["joker_smile"]
      refute Object.normalize(reply_activity).data["emoji"]["joker_disapprove"]
    end

    test "deactivated users can't post" do
      user = insert(:user, is_active: false)
      assert {:error, _} = CommonAPI.post(user, %{status: "ye"})
    end

    test "it supports explicit addressing" do
      user = insert(:user)
      user_two = insert(:user)
      user_three = insert(:user)
      user_four = insert(:user)

      {:ok, activity} =
        CommonAPI.post(user, %{
          status:
            "Hey, I think @#{user_three.nickname} is ugly. @#{user_four.nickname} is alright though.",
          to: [user_two.nickname, user_four.nickname, "nonexistent"]
        })

      assert user.ap_id in activity.recipients
      assert user_two.ap_id in activity.recipients
      assert user_four.ap_id in activity.recipients
      refute user_three.ap_id in activity.recipients
    end

    test "it filters out obviously bad tags when accepting a post as HTML" do
      user = insert(:user)

      post = "<p><b>2hu</b></p><script>alert('xss')</script>"

      {:ok, activity} =
        CommonAPI.post(user, %{
          status: post,
          content_type: "text/html"
        })

      object = Object.normalize(activity, fetch: false)

      assert object.data["content"] == "<p><b>2hu</b></p>alert(&#39;xss&#39;)"
      assert object.data["source"] == post
    end

    test "it filters out obviously bad tags when accepting a post as Markdown" do
      user = insert(:user)

      post = "<p><b>2hu</b></p><script>alert('xss')</script>"

      {:ok, activity} =
        CommonAPI.post(user, %{
          status: post,
          content_type: "text/markdown"
        })

      object = Object.normalize(activity, fetch: false)

      assert object.data["content"] == "<p><b>2hu</b></p>"
      assert object.data["source"] == post
    end

    test "it does not allow replies to direct messages that are not direct messages themselves" do
      user = insert(:user)

      {:ok, activity} = CommonAPI.post(user, %{status: "suya..", visibility: "direct"})

      assert {:ok, _} =
               CommonAPI.post(user, %{
                 status: "suya..",
                 visibility: "direct",
                 in_reply_to_status_id: activity.id
               })

      Enum.each(["public", "private", "unlisted"], fn visibility ->
        assert {:error, "The message visibility must be direct"} =
                 CommonAPI.post(user, %{
                   status: "suya..",
                   visibility: visibility,
                   in_reply_to_status_id: activity.id
                 })
      end)
    end

    test "replying with a direct message will NOT auto-add the author of the reply to the recipient list" do
      user = insert(:user)
      other_user = insert(:user)
      third_user = insert(:user)

      {:ok, post} = CommonAPI.post(user, %{status: "I'm stupid"})

      {:ok, open_answer} =
        CommonAPI.post(other_user, %{status: "No ur smart", in_reply_to_status_id: post.id})

      # The OP is implicitly added
      assert user.ap_id in open_answer.recipients

      {:ok, secret_answer} =
        CommonAPI.post(other_user, %{
          status: "lol, that guy really is stupid, right, @#{third_user.nickname}?",
          in_reply_to_status_id: post.id,
          visibility: "direct"
        })

      assert third_user.ap_id in secret_answer.recipients

      # The OP is not added
      refute user.ap_id in secret_answer.recipients
    end

    test "it allows to address a list" do
      user = insert(:user)
      {:ok, list} = Pleroma.List.create("foo", user)

      {:ok, activity} = CommonAPI.post(user, %{status: "foobar", visibility: "list:#{list.id}"})

      assert activity.data["bcc"] == [list.ap_id]
      assert activity.recipients == [list.ap_id, user.ap_id]
      assert activity.data["listMessage"] == list.ap_id
    end

    test "it returns error when status is empty and no attachments" do
      user = insert(:user)

      assert {:error, "Cannot post an empty status without attachments"} =
               CommonAPI.post(user, %{status: ""})
    end

    test "it validates character limits are correctly enforced" do
      clear_config([:instance, :limit], 5)

      user = insert(:user)

      assert {:error, "The status is over the character limit"} =
               CommonAPI.post(user, %{status: "foobar"})

      assert {:ok, _activity} = CommonAPI.post(user, %{status: "12345"})
    end

    test "it validates media attachment limits are correctly enforced" do
      clear_config([:instance, :max_media_attachments], 4)

      user = insert(:user)

      file = %Plug.Upload{
        content_type: "image/jpeg",
        path: Path.absname("test/fixtures/image.jpg"),
        filename: "an_image.jpg"
      }

      {:ok, upload} = ActivityPub.upload(file, actor: user.ap_id)

      assert {:error, "Too many attachments"} =
               CommonAPI.post(user, %{
                 status: "",
                 media_ids: List.duplicate(upload.id, 5)
               })

      assert {:ok, _activity} =
               CommonAPI.post(user, %{
                 status: "",
                 media_ids: [upload.id]
               })
    end

    test "it can handle activities that expire" do
      user = insert(:user)

      expires_at = DateTime.add(DateTime.utc_now(), 1_000_000)

      assert {:ok, activity} = CommonAPI.post(user, %{status: "chai", expires_in: 1_000_000})

      assert_enqueued(
        worker: Pleroma.Workers.PurgeExpiredActivity,
        args: %{activity_id: activity.id},
        scheduled_at: expires_at
      )
    end
  end

  describe "reactions" do
    test "reacting to a status with an emoji" do
      user = insert(:user)
      other_user = insert(:user)

      {:ok, activity} = CommonAPI.post(other_user, %{status: "cofe"})

      {:ok, reaction} = CommonAPI.react_with_emoji(activity.id, user, "👍")

      assert reaction.data["actor"] == user.ap_id
      assert reaction.data["content"] == "👍"

      {:ok, activity} = CommonAPI.post(other_user, %{status: "cofe"})

      {:error, _} = CommonAPI.react_with_emoji(activity.id, user, ".")
    end

    test "unreacting to a status with an emoji" do
      user = insert(:user)
      other_user = insert(:user)

      clear_config([:instance, :federating], true)

      with_mock Pleroma.Web.Federator,
        publish: fn _ -> nil end do
        {:ok, activity} = CommonAPI.post(other_user, %{status: "cofe"})
        {:ok, reaction} = CommonAPI.react_with_emoji(activity.id, user, "👍")

        {:ok, unreaction} = CommonAPI.unreact_with_emoji(activity.id, user, "👍")

        assert unreaction.data["type"] == "Undo"
        assert unreaction.data["object"] == reaction.data["id"]
        assert unreaction.local

        # On federation, it contains the undone (and deleted) object
        unreaction_with_object = %{
          unreaction
          | data: Map.put(unreaction.data, "object", reaction.data)
        }

        assert called(Pleroma.Web.Federator.publish(unreaction_with_object))
      end
    end

    test "repeating a status" do
      user = insert(:user)
      other_user = insert(:user)

      {:ok, activity} = CommonAPI.post(other_user, %{status: "cofe"})

      {:ok, %Activity{} = announce_activity} = CommonAPI.repeat(activity.id, user)
      assert Visibility.is_public?(announce_activity)
    end

    test "can't repeat a repeat" do
      user = insert(:user)
      other_user = insert(:user)
      {:ok, activity} = CommonAPI.post(other_user, %{status: "cofe"})

      {:ok, %Activity{} = announce} = CommonAPI.repeat(activity.id, other_user)

      refute match?({:ok, %Activity{}}, CommonAPI.repeat(announce.id, user))
    end

    test "repeating a status privately" do
      user = insert(:user)
      other_user = insert(:user)

      {:ok, activity} = CommonAPI.post(other_user, %{status: "cofe"})

      {:ok, %Activity{} = announce_activity} =
        CommonAPI.repeat(activity.id, user, %{visibility: "private"})

      assert Visibility.is_private?(announce_activity)
      refute Visibility.visible_for_user?(announce_activity, nil)
    end

    test "author can repeat own private statuses" do
      author = insert(:user)
      follower = insert(:user)
      CommonAPI.follow(follower, author)

      {:ok, activity} = CommonAPI.post(author, %{status: "cofe", visibility: "private"})

      {:ok, %Activity{} = announce_activity} = CommonAPI.repeat(activity.id, author)

      assert Visibility.is_private?(announce_activity)
      refute Visibility.visible_for_user?(announce_activity, nil)

      assert Visibility.visible_for_user?(activity, follower)
      assert {:error, :not_found} = CommonAPI.repeat(activity.id, follower)
    end

    test "favoriting a status" do
      user = insert(:user)
      other_user = insert(:user)

      {:ok, post_activity} = CommonAPI.post(other_user, %{status: "cofe"})

      {:ok, %Activity{data: data}} = CommonAPI.favorite(user, post_activity.id)
      assert data["type"] == "Like"
      assert data["actor"] == user.ap_id
      assert data["object"] == post_activity.data["object"]
    end

    test "retweeting a status twice returns the status" do
      user = insert(:user)
      other_user = insert(:user)

      {:ok, activity} = CommonAPI.post(other_user, %{status: "cofe"})
      {:ok, %Activity{} = announce} = CommonAPI.repeat(activity.id, user)
      {:ok, ^announce} = CommonAPI.repeat(activity.id, user)
    end

    test "favoriting a status twice returns ok, but without the like activity" do
      user = insert(:user)
      other_user = insert(:user)

      {:ok, activity} = CommonAPI.post(other_user, %{status: "cofe"})
      {:ok, %Activity{}} = CommonAPI.favorite(user, activity.id)
      assert {:ok, :already_liked} = CommonAPI.favorite(user, activity.id)
    end
  end

  describe "pinned statuses" do
    setup do
      clear_config([:instance, :max_pinned_statuses], 1)

      user = insert(:user)
      {:ok, activity} = CommonAPI.post(user, %{status: "HI!!!"})

      [user: user, activity: activity]
    end

    test "activity not found error", %{user: user} do
      assert {:error, :not_found} = CommonAPI.pin("id", user)
    end

    test "pin status", %{user: user, activity: activity} do
      assert {:ok, ^activity} = CommonAPI.pin(activity.id, user)

      %{data: %{"id" => object_id}} = Object.normalize(activity)
      user = refresh_record(user)

      assert user.pinned_objects |> Map.keys() == [object_id]
    end

    test "pin poll", %{user: user} do
      {:ok, activity} =
        CommonAPI.post(user, %{
          status: "How is fediverse today?",
          poll: %{options: ["Absolutely outstanding", "Not good"], expires_in: 20}
        })

      assert {:ok, ^activity} = CommonAPI.pin(activity.id, user)

      %{data: %{"id" => object_id}} = Object.normalize(activity)

      user = refresh_record(user)

      assert user.pinned_objects |> Map.keys() == [object_id]
    end

    test "unlisted statuses can be pinned", %{user: user} do
      {:ok, activity} = CommonAPI.post(user, %{status: "HI!!!", visibility: "unlisted"})
      assert {:ok, ^activity} = CommonAPI.pin(activity.id, user)
    end

    test "only self-authored can be pinned", %{activity: activity} do
      user = insert(:user)

      assert {:error, :ownership_error} = CommonAPI.pin(activity.id, user)
    end

    test "max pinned statuses", %{user: user, activity: activity_one} do
      {:ok, activity_two} = CommonAPI.post(user, %{status: "HI!!!"})

      assert {:ok, ^activity_one} = CommonAPI.pin(activity_one.id, user)

      user = refresh_record(user)

      assert {:error, :pinned_statuses_limit_reached} = CommonAPI.pin(activity_two.id, user)
    end

    test "only public can be pinned", %{user: user} do
      {:ok, activity} = CommonAPI.post(user, %{status: "private status", visibility: "private"})
      {:error, :visibility_error} = CommonAPI.pin(activity.id, user)
    end

    test "unpin status", %{user: user, activity: activity} do
      {:ok, activity} = CommonAPI.pin(activity.id, user)

      user = refresh_record(user)

      id = activity.id

      assert match?({:ok, %{id: ^id}}, CommonAPI.unpin(activity.id, user))

      user = refresh_record(user)

      assert user.pinned_objects == %{}
    end

    test "should unpin when deleting a status", %{user: user, activity: activity} do
      {:ok, activity} = CommonAPI.pin(activity.id, user)

      user = refresh_record(user)

      assert {:ok, _} = CommonAPI.delete(activity.id, user)

      user = refresh_record(user)

      assert user.pinned_objects == %{}
    end

    test "ephemeral activity won't be deleted if was pinned", %{user: user} do
      {:ok, activity} = CommonAPI.post(user, %{status: "Hello!", expires_in: 601})

      assert Pleroma.Workers.PurgeExpiredActivity.get_expiration(activity.id)

      {:ok, _activity} = CommonAPI.pin(activity.id, user)
      refute Pleroma.Workers.PurgeExpiredActivity.get_expiration(activity.id)

      user = refresh_record(user)
      {:ok, _} = CommonAPI.unpin(activity.id, user)

      # recreates expiration job on unpin
      assert Pleroma.Workers.PurgeExpiredActivity.get_expiration(activity.id)
    end

    test "ephemeral activity deletion job won't be deleted on pinning error", %{
      user: user,
      activity: activity
    } do
      clear_config([:instance, :max_pinned_statuses], 1)

      {:ok, _activity} = CommonAPI.pin(activity.id, user)

      {:ok, activity2} = CommonAPI.post(user, %{status: "another status", expires_in: 601})

      assert Pleroma.Workers.PurgeExpiredActivity.get_expiration(activity2.id)

      user = refresh_record(user)
      {:error, :pinned_statuses_limit_reached} = CommonAPI.pin(activity2.id, user)

      assert Pleroma.Workers.PurgeExpiredActivity.get_expiration(activity2.id)
    end
  end

  describe "mute tests" do
    setup do
      user = insert(:user)

      activity = insert(:note_activity)

      [user: user, activity: activity]
    end

    test "marks notifications as read after mute" do
      author = insert(:user)
      activity = insert(:note_activity, user: author)

      friend1 = insert(:user)
      friend2 = insert(:user)

      {:ok, reply_activity} =
        CommonAPI.post(
          friend2,
          %{
            status: "@#{author.nickname} @#{friend1.nickname} test reply",
            in_reply_to_status_id: activity.id
          }
        )

      {:ok, favorite_activity} = CommonAPI.favorite(friend2, activity.id)
      {:ok, repeat_activity} = CommonAPI.repeat(activity.id, friend1)

      assert Repo.aggregate(
               from(n in Notification, where: n.seen == false and n.user_id == ^friend1.id),
               :count
             ) == 1

      unread_notifications =
        Repo.all(from(n in Notification, where: n.seen == false, where: n.user_id == ^author.id))

      assert Enum.any?(unread_notifications, fn n ->
               n.type == "favourite" && n.activity_id == favorite_activity.id
             end)

      assert Enum.any?(unread_notifications, fn n ->
               n.type == "reblog" && n.activity_id == repeat_activity.id
             end)

      assert Enum.any?(unread_notifications, fn n ->
               n.type == "mention" && n.activity_id == reply_activity.id
             end)

      {:ok, _} = CommonAPI.add_mute(author, activity)
      assert CommonAPI.thread_muted?(author, activity)

      assert Repo.aggregate(
               from(n in Notification, where: n.seen == false and n.user_id == ^friend1.id),
               :count
             ) == 1

      read_notifications =
        Repo.all(from(n in Notification, where: n.seen == true, where: n.user_id == ^author.id))

      assert Enum.any?(read_notifications, fn n ->
               n.type == "favourite" && n.activity_id == favorite_activity.id
             end)

      assert Enum.any?(read_notifications, fn n ->
               n.type == "reblog" && n.activity_id == repeat_activity.id
             end)

      assert Enum.any?(read_notifications, fn n ->
               n.type == "mention" && n.activity_id == reply_activity.id
             end)
    end

    test "add mute", %{user: user, activity: activity} do
      {:ok, _} = CommonAPI.add_mute(user, activity)
      assert CommonAPI.thread_muted?(user, activity)
    end

    test "add expiring mute", %{user: user, activity: activity} do
      {:ok, _} = CommonAPI.add_mute(user, activity, %{expires_in: 60})
      assert CommonAPI.thread_muted?(user, activity)

      worker = Pleroma.Workers.MuteExpireWorker
      args = %{"op" => "unmute_conversation", "user_id" => user.id, "activity_id" => activity.id}

      assert_enqueued(
        worker: worker,
        args: args
      )

      assert :ok = perform_job(worker, args)
      refute CommonAPI.thread_muted?(user, activity)
    end

    test "remove mute", %{user: user, activity: activity} do
      CommonAPI.add_mute(user, activity)
      {:ok, _} = CommonAPI.remove_mute(user, activity)
      refute CommonAPI.thread_muted?(user, activity)
    end

    test "remove mute by ids", %{user: user, activity: activity} do
      CommonAPI.add_mute(user, activity)
      {:ok, _} = CommonAPI.remove_mute(user.id, activity.id)
      refute CommonAPI.thread_muted?(user, activity)
    end

    test "check that mutes can't be duplicate", %{user: user, activity: activity} do
      CommonAPI.add_mute(user, activity)
      {:error, _} = CommonAPI.add_mute(user, activity)
    end
  end

  describe "reports" do
    test "creates a report" do
      reporter = insert(:user)
      target_user = insert(:user)

      {:ok, activity} = CommonAPI.post(target_user, %{status: "foobar"})

      reporter_ap_id = reporter.ap_id
      target_ap_id = target_user.ap_id
      activity_ap_id = activity.data["id"]
      comment = "foobar"

      report_data = %{
        account_id: target_user.id,
        comment: comment,
        status_ids: [activity.id]
      }

      note_obj = %{
        "type" => "Note",
        "id" => activity_ap_id,
        "content" => "foobar",
        "published" => activity.object.data["published"],
        "actor" => AccountView.render("show.json", %{user: target_user})
      }

      assert {:ok, flag_activity} = CommonAPI.report(reporter, report_data)

      assert %Activity{
               actor: ^reporter_ap_id,
               data: %{
                 "type" => "Flag",
                 "content" => ^comment,
                 "object" => [^target_ap_id, ^note_obj],
                 "state" => "open"
               }
             } = flag_activity
    end

    test "updates report state" do
      [reporter, target_user] = insert_pair(:user)
      activity = insert(:note_activity, user: target_user)

      {:ok, %Activity{id: report_id}} =
        CommonAPI.report(reporter, %{
          account_id: target_user.id,
          comment: "I feel offended",
          status_ids: [activity.id]
        })

      {:ok, report} = CommonAPI.update_report_state(report_id, "resolved")

      assert report.data["state"] == "resolved"

      [reported_user, activity_id] = report.data["object"]

      assert reported_user == target_user.ap_id
      assert activity_id == activity.data["id"]
    end

    test "does not update report state when state is unsupported" do
      [reporter, target_user] = insert_pair(:user)
      activity = insert(:note_activity, user: target_user)

      {:ok, %Activity{id: report_id}} =
        CommonAPI.report(reporter, %{
          account_id: target_user.id,
          comment: "I feel offended",
          status_ids: [activity.id]
        })

      assert CommonAPI.update_report_state(report_id, "test") == {:error, "Unsupported state"}
    end

    test "updates state of multiple reports" do
      [reporter, target_user] = insert_pair(:user)
      activity = insert(:note_activity, user: target_user)

      {:ok, %Activity{id: first_report_id}} =
        CommonAPI.report(reporter, %{
          account_id: target_user.id,
          comment: "I feel offended",
          status_ids: [activity.id]
        })

      {:ok, %Activity{id: second_report_id}} =
        CommonAPI.report(reporter, %{
          account_id: target_user.id,
          comment: "I feel very offended!",
          status_ids: [activity.id]
        })

      {:ok, report_ids} =
        CommonAPI.update_report_state([first_report_id, second_report_id], "resolved")

      first_report = Activity.get_by_id(first_report_id)
      second_report = Activity.get_by_id(second_report_id)

      assert report_ids -- [first_report_id, second_report_id] == []
      assert first_report.data["state"] == "resolved"
      assert second_report.data["state"] == "resolved"
    end
  end

  describe "reblog muting" do
    setup do
      muter = insert(:user)

      muted = insert(:user)

      [muter: muter, muted: muted]
    end

    test "add a reblog mute", %{muter: muter, muted: muted} do
      {:ok, _reblog_mute} = CommonAPI.hide_reblogs(muter, muted)

      assert User.showing_reblogs?(muter, muted) == false
    end

    test "remove a reblog mute", %{muter: muter, muted: muted} do
      {:ok, _reblog_mute} = CommonAPI.hide_reblogs(muter, muted)
      {:ok, _reblog_mute} = CommonAPI.show_reblogs(muter, muted)

      assert User.showing_reblogs?(muter, muted) == true
    end
  end

  describe "follow/2" do
    test "directly follows a non-locked local user" do
      [follower, followed] = insert_pair(:user)
      {:ok, follower, followed, _} = CommonAPI.follow(follower, followed)

      assert User.following?(follower, followed)
    end
  end

  describe "unfollow/2" do
    test "also unsubscribes a user" do
      [follower, followed] = insert_pair(:user)
      {:ok, follower, followed, _} = CommonAPI.follow(follower, followed)
      {:ok, _subscription} = User.subscribe(follower, followed)

      assert User.subscribed_to?(follower, followed)

      {:ok, follower} = CommonAPI.unfollow(follower, followed)

      refute User.subscribed_to?(follower, followed)
    end

    test "also unpins a user" do
      [follower, followed] = insert_pair(:user)
      {:ok, follower, followed, _} = CommonAPI.follow(follower, followed)
      {:ok, _endorsement} = User.endorse(follower, followed)

      assert User.endorses?(follower, followed)

      {:ok, follower} = CommonAPI.unfollow(follower, followed)

      refute User.endorses?(follower, followed)
    end

    test "cancels a pending follow for a local user" do
      follower = insert(:user)
      followed = insert(:user, is_locked: true)

      assert {:ok, follower, followed, %{id: activity_id, data: %{"state" => "pending"}}} =
               CommonAPI.follow(follower, followed)

      assert User.get_follow_state(follower, followed) == :follow_pending
      assert {:ok, follower} = CommonAPI.unfollow(follower, followed)
      assert User.get_follow_state(follower, followed) == nil

      assert %{id: ^activity_id, data: %{"state" => "cancelled"}} =
               Pleroma.Web.ActivityPub.Utils.fetch_latest_follow(follower, followed)

      assert %{
               data: %{
                 "type" => "Undo",
                 "object" => %{"type" => "Follow", "state" => "cancelled"}
               }
             } = Pleroma.Web.ActivityPub.Utils.fetch_latest_undo(follower)
    end

    test "cancels a pending follow for a remote user" do
      follower = insert(:user)
      followed = insert(:user, is_locked: true, local: false, ap_enabled: true)

      assert {:ok, follower, followed, %{id: activity_id, data: %{"state" => "pending"}}} =
               CommonAPI.follow(follower, followed)

      assert User.get_follow_state(follower, followed) == :follow_pending
      assert {:ok, follower} = CommonAPI.unfollow(follower, followed)
      assert User.get_follow_state(follower, followed) == nil

      assert %{id: ^activity_id, data: %{"state" => "cancelled"}} =
               Pleroma.Web.ActivityPub.Utils.fetch_latest_follow(follower, followed)

      assert %{
               data: %{
                 "type" => "Undo",
                 "object" => %{"type" => "Follow", "state" => "cancelled"}
               }
             } = Pleroma.Web.ActivityPub.Utils.fetch_latest_undo(follower)
    end
  end

  describe "accept_follow_request/2" do
    test "after acceptance, it sets all existing pending follow request states to 'accept'" do
      user = insert(:user, is_locked: true)
      follower = insert(:user)
      follower_two = insert(:user)

      {:ok, _, _, follow_activity} = CommonAPI.follow(follower, user)
      {:ok, _, _, follow_activity_two} = CommonAPI.follow(follower, user)
      {:ok, _, _, follow_activity_three} = CommonAPI.follow(follower_two, user)

      assert follow_activity.data["state"] == "pending"
      assert follow_activity_two.data["state"] == "pending"
      assert follow_activity_three.data["state"] == "pending"

      {:ok, _follower} = CommonAPI.accept_follow_request(follower, user)

      assert Repo.get(Activity, follow_activity.id).data["state"] == "accept"
      assert Repo.get(Activity, follow_activity_two.id).data["state"] == "accept"
      assert Repo.get(Activity, follow_activity_three.id).data["state"] == "pending"
    end

    test "after rejection, it sets all existing pending follow request states to 'reject'" do
      user = insert(:user, is_locked: true)
      follower = insert(:user)
      follower_two = insert(:user)

      {:ok, _, _, follow_activity} = CommonAPI.follow(follower, user)
      {:ok, _, _, follow_activity_two} = CommonAPI.follow(follower, user)
      {:ok, _, _, follow_activity_three} = CommonAPI.follow(follower_two, user)

      assert follow_activity.data["state"] == "pending"
      assert follow_activity_two.data["state"] == "pending"
      assert follow_activity_three.data["state"] == "pending"

      {:ok, _follower} = CommonAPI.reject_follow_request(follower, user)

      assert Repo.get(Activity, follow_activity.id).data["state"] == "reject"
      assert Repo.get(Activity, follow_activity_two.id).data["state"] == "reject"
      assert Repo.get(Activity, follow_activity_three.id).data["state"] == "pending"
    end

    test "doesn't create a following relationship if the corresponding follow request doesn't exist" do
      user = insert(:user, is_locked: true)
      not_follower = insert(:user)
      CommonAPI.accept_follow_request(not_follower, user)

      assert Pleroma.FollowingRelationship.following?(not_follower, user) == false
    end
  end

  describe "vote/3" do
    test "does not allow to vote twice" do
      user = insert(:user)
      other_user = insert(:user)

      {:ok, activity} =
        CommonAPI.post(user, %{
          status: "Am I cute?",
          poll: %{options: ["Yes", "No"], expires_in: 20}
        })

      object = Object.normalize(activity, fetch: false)

      {:ok, _, object} = CommonAPI.vote(other_user, object, [0])

      assert {:error, "Already voted"} == CommonAPI.vote(other_user, object, [1])
    end
  end

  describe "listen/2" do
    test "returns a valid activity" do
      user = insert(:user)

      {:ok, activity} =
        CommonAPI.listen(user, %{
          title: "lain radio episode 1",
          album: "lain radio",
          artist: "lain",
          length: 180_000
        })

      object = Object.normalize(activity, fetch: false)

      assert object.data["title"] == "lain radio episode 1"

      assert Visibility.get_visibility(activity) == "public"
    end

    test "respects visibility=private" do
      user = insert(:user)

      {:ok, activity} =
        CommonAPI.listen(user, %{
          title: "lain radio episode 1",
          album: "lain radio",
          artist: "lain",
          length: 180_000,
          visibility: "private"
        })

      object = Object.normalize(activity, fetch: false)

      assert object.data["title"] == "lain radio episode 1"

      assert Visibility.get_visibility(activity) == "private"
    end
  end

  describe "get_user/1" do
    test "gets user by ap_id" do
      user = insert(:user)
      assert CommonAPI.get_user(user.ap_id) == user
    end

    test "gets user by guessed nickname" do
      user = insert(:user, ap_id: "", nickname: "mario@mushroom.kingdom")
      assert CommonAPI.get_user("https://mushroom.kingdom/users/mario") == user
    end

    test "fallback" do
      assert %User{
               name: "",
               ap_id: "",
               nickname: "erroruser@example.com"
             } = CommonAPI.get_user("")
    end
  end

  describe "with `local` visibility" do
    setup do: clear_config([:instance, :federating], true)

    test "post" do
      user = insert(:user)

      with_mock Pleroma.Web.Federator, publish: fn _ -> :ok end do
        {:ok, activity} = CommonAPI.post(user, %{status: "#2hu #2HU", visibility: "local"})

        assert Visibility.is_local_public?(activity)
        assert_not_called(Pleroma.Web.Federator.publish(activity))
      end
    end

    test "delete" do
      user = insert(:user)

      {:ok, %Activity{id: activity_id}} =
        CommonAPI.post(user, %{status: "#2hu #2HU", visibility: "local"})

      with_mock Pleroma.Web.Federator, publish: fn _ -> :ok end do
        assert {:ok, %Activity{data: %{"deleted_activity_id" => ^activity_id}} = activity} =
                 CommonAPI.delete(activity_id, user)

        assert Visibility.is_local_public?(activity)
        assert_not_called(Pleroma.Web.Federator.publish(activity))
      end
    end

    test "repeat" do
      user = insert(:user)
      other_user = insert(:user)

      {:ok, %Activity{id: activity_id}} =
        CommonAPI.post(other_user, %{status: "cofe", visibility: "local"})

      with_mock Pleroma.Web.Federator, publish: fn _ -> :ok end do
        assert {:ok, %Activity{data: %{"type" => "Announce"}} = activity} =
                 CommonAPI.repeat(activity_id, user)

        assert Visibility.is_local_public?(activity)
        refute called(Pleroma.Web.Federator.publish(activity))
      end
    end

    test "unrepeat" do
      user = insert(:user)
      other_user = insert(:user)

      {:ok, %Activity{id: activity_id}} =
        CommonAPI.post(other_user, %{status: "cofe", visibility: "local"})

      assert {:ok, _} = CommonAPI.repeat(activity_id, user)

      with_mock Pleroma.Web.Federator, publish: fn _ -> :ok end do
        assert {:ok, %Activity{data: %{"type" => "Undo"}} = activity} =
                 CommonAPI.unrepeat(activity_id, user)

        assert Visibility.is_local_public?(activity)
        refute called(Pleroma.Web.Federator.publish(activity))
      end
    end

    test "favorite" do
      user = insert(:user)
      other_user = insert(:user)

      {:ok, activity} = CommonAPI.post(other_user, %{status: "cofe", visibility: "local"})

      with_mock Pleroma.Web.Federator, publish: fn _ -> :ok end do
        assert {:ok, %Activity{data: %{"type" => "Like"}} = activity} =
                 CommonAPI.favorite(user, activity.id)

        assert Visibility.is_local_public?(activity)
        refute called(Pleroma.Web.Federator.publish(activity))
      end
    end

    test "unfavorite" do
      user = insert(:user)
      other_user = insert(:user)

      {:ok, activity} = CommonAPI.post(other_user, %{status: "cofe", visibility: "local"})

      {:ok, %Activity{}} = CommonAPI.favorite(user, activity.id)

      with_mock Pleroma.Web.Federator, publish: fn _ -> :ok end do
        assert {:ok, activity} = CommonAPI.unfavorite(activity.id, user)
        assert Visibility.is_local_public?(activity)
        refute called(Pleroma.Web.Federator.publish(activity))
      end
    end

    test "react_with_emoji" do
      user = insert(:user)
      other_user = insert(:user)
      {:ok, activity} = CommonAPI.post(other_user, %{status: "cofe", visibility: "local"})

      with_mock Pleroma.Web.Federator, publish: fn _ -> :ok end do
        assert {:ok, %Activity{data: %{"type" => "EmojiReact"}} = activity} =
                 CommonAPI.react_with_emoji(activity.id, user, "👍")

        assert Visibility.is_local_public?(activity)
        refute called(Pleroma.Web.Federator.publish(activity))
      end
    end

    test "unreact_with_emoji" do
      user = insert(:user)
      other_user = insert(:user)
      {:ok, activity} = CommonAPI.post(other_user, %{status: "cofe", visibility: "local"})

      {:ok, _reaction} = CommonAPI.react_with_emoji(activity.id, user, "👍")

      with_mock Pleroma.Web.Federator, publish: fn _ -> :ok end do
        assert {:ok, %Activity{data: %{"type" => "Undo"}} = activity} =
                 CommonAPI.unreact_with_emoji(activity.id, user, "👍")

        assert Visibility.is_local_public?(activity)
        refute called(Pleroma.Web.Federator.publish(activity))
      end
    end
  end
end
