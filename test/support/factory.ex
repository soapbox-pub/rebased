# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Factory do
  use ExMachina.Ecto, repo: Pleroma.Repo
  alias Pleroma.Object
  alias Pleroma.User

  def participation_factory do
    conversation = insert(:conversation)
    user = insert(:user)

    %Pleroma.Conversation.Participation{
      conversation: conversation,
      user: user,
      read: false
    }
  end

  def conversation_factory do
    %Pleroma.Conversation{
      ap_id: sequence(:ap_id, &"https://some_conversation/#{&1}")
    }
  end

  def user_factory do
    user = %User{
      name: sequence(:name, &"Test テスト User #{&1}"),
      email: sequence(:email, &"user#{&1}@example.com"),
      nickname: sequence(:nickname, &"nick#{&1}"),
      password_hash: Comeonin.Pbkdf2.hashpwsalt("test"),
      bio: sequence(:bio, &"Tester Number #{&1}"),
      last_digest_emailed_at: NaiveDateTime.utc_now()
    }

    %{
      user
      | ap_id: User.ap_id(user),
        follower_address: User.ap_followers(user),
        following_address: User.ap_following(user)
    }
  end

  def user_relationship_factory(attrs \\ %{}) do
    source = attrs[:source] || insert(:user)
    target = attrs[:target] || insert(:user)
    relationship_type = attrs[:relationship_type] || :block

    %Pleroma.UserRelationship{
      source_id: source.id,
      target_id: target.id,
      relationship_type: relationship_type
    }
  end

  def note_factory(attrs \\ %{}) do
    text = sequence(:text, &"This is :moominmamma: note #{&1}")

    user = attrs[:user] || insert(:user)

    data = %{
      "type" => "Note",
      "content" => text,
      "id" => Pleroma.Web.ActivityPub.Utils.generate_object_id(),
      "actor" => user.ap_id,
      "to" => ["https://www.w3.org/ns/activitystreams#Public"],
      "published" => DateTime.utc_now() |> DateTime.to_iso8601(),
      "likes" => [],
      "like_count" => 0,
      "context" => "2hu",
      "summary" => "2hu",
      "tag" => ["2hu"],
      "emoji" => %{
        "2hu" => "corndog.png"
      }
    }

    %Pleroma.Object{
      data: merge_attributes(data, Map.get(attrs, :data, %{}))
    }
  end

  def audio_factory(attrs \\ %{}) do
    text = sequence(:text, &"lain radio episode #{&1}")

    user = attrs[:user] || insert(:user)

    data = %{
      "type" => "Audio",
      "id" => Pleroma.Web.ActivityPub.Utils.generate_object_id(),
      "artist" => "lain",
      "title" => text,
      "album" => "lain radio",
      "to" => ["https://www.w3.org/ns/activitystreams#Public"],
      "published" => DateTime.utc_now() |> DateTime.to_iso8601(),
      "actor" => user.ap_id,
      "length" => 180_000
    }

    %Pleroma.Object{
      data: merge_attributes(data, Map.get(attrs, :data, %{}))
    }
  end

  def listen_factory do
    audio = insert(:audio)

    data = %{
      "id" => Pleroma.Web.ActivityPub.Utils.generate_activity_id(),
      "type" => "Listen",
      "actor" => audio.data["actor"],
      "to" => audio.data["to"],
      "object" => audio.data,
      "published" => audio.data["published"]
    }

    %Pleroma.Activity{
      data: data,
      actor: data["actor"],
      recipients: data["to"]
    }
  end

  def direct_note_factory do
    user2 = insert(:user)

    %Pleroma.Object{data: data} = note_factory()
    %Pleroma.Object{data: Map.merge(data, %{"to" => [user2.ap_id]})}
  end

  def article_factory do
    note_factory()
    |> Map.put("type", "Article")
  end

  def tombstone_factory do
    data = %{
      "type" => "Tombstone",
      "id" => Pleroma.Web.ActivityPub.Utils.generate_object_id(),
      "formerType" => "Note",
      "deleted" => DateTime.utc_now() |> DateTime.to_iso8601()
    }

    %Pleroma.Object{
      data: data
    }
  end

  def direct_note_activity_factory do
    dm = insert(:direct_note)

    data = %{
      "id" => Pleroma.Web.ActivityPub.Utils.generate_activity_id(),
      "type" => "Create",
      "actor" => dm.data["actor"],
      "to" => dm.data["to"],
      "object" => dm.data,
      "published" => DateTime.utc_now() |> DateTime.to_iso8601(),
      "context" => dm.data["context"]
    }

    %Pleroma.Activity{
      data: data,
      actor: data["actor"],
      recipients: data["to"]
    }
  end

  def note_activity_factory(attrs \\ %{}) do
    user = attrs[:user] || insert(:user)
    note = attrs[:note] || insert(:note, user: user)

    data_attrs = attrs[:data_attrs] || %{}
    attrs = Map.drop(attrs, [:user, :note, :data_attrs])

    data =
      %{
        "id" => Pleroma.Web.ActivityPub.Utils.generate_activity_id(),
        "type" => "Create",
        "actor" => note.data["actor"],
        "to" => note.data["to"],
        "object" => note.data["id"],
        "published" => DateTime.utc_now() |> DateTime.to_iso8601(),
        "context" => note.data["context"]
      }
      |> Map.merge(data_attrs)

    %Pleroma.Activity{
      data: data,
      actor: data["actor"],
      recipients: data["to"]
    }
    |> Map.merge(attrs)
  end

  defp expiration_offset_by_minutes(attrs, minutes) do
    scheduled_at =
      NaiveDateTime.utc_now()
      |> NaiveDateTime.add(:timer.minutes(minutes), :millisecond)
      |> NaiveDateTime.truncate(:second)

    %Pleroma.ActivityExpiration{}
    |> Map.merge(attrs)
    |> Map.put(:scheduled_at, scheduled_at)
  end

  def expiration_in_the_past_factory(attrs \\ %{}) do
    expiration_offset_by_minutes(attrs, -60)
  end

  def expiration_in_the_future_factory(attrs \\ %{}) do
    expiration_offset_by_minutes(attrs, 61)
  end

  def article_activity_factory do
    article = insert(:article)

    data = %{
      "id" => Pleroma.Web.ActivityPub.Utils.generate_activity_id(),
      "type" => "Create",
      "actor" => article.data["actor"],
      "to" => article.data["to"],
      "object" => article.data,
      "published" => DateTime.utc_now() |> DateTime.to_iso8601(),
      "context" => article.data["context"]
    }

    %Pleroma.Activity{
      data: data,
      actor: data["actor"],
      recipients: data["to"]
    }
  end

  def announce_activity_factory(attrs \\ %{}) do
    note_activity = attrs[:note_activity] || insert(:note_activity)
    user = attrs[:user] || insert(:user)

    data = %{
      "type" => "Announce",
      "actor" => note_activity.actor,
      "object" => note_activity.data["id"],
      "to" => [user.follower_address, note_activity.data["actor"]],
      "cc" => ["https://www.w3.org/ns/activitystreams#Public"],
      "context" => note_activity.data["context"]
    }

    %Pleroma.Activity{
      data: data,
      actor: user.ap_id,
      recipients: data["to"]
    }
  end

  def like_activity_factory(attrs \\ %{}) do
    note_activity = attrs[:note_activity] || insert(:note_activity)
    object = Object.normalize(note_activity)
    user = insert(:user)

    data =
      %{
        "id" => Pleroma.Web.ActivityPub.Utils.generate_activity_id(),
        "actor" => user.ap_id,
        "type" => "Like",
        "object" => object.data["id"],
        "published_at" => DateTime.utc_now() |> DateTime.to_iso8601()
      }
      |> Map.merge(attrs[:data_attrs] || %{})

    %Pleroma.Activity{
      data: data
    }
  end

  def follow_activity_factory do
    follower = insert(:user)
    followed = insert(:user)

    data = %{
      "id" => Pleroma.Web.ActivityPub.Utils.generate_activity_id(),
      "actor" => follower.ap_id,
      "type" => "Follow",
      "object" => followed.ap_id,
      "published_at" => DateTime.utc_now() |> DateTime.to_iso8601()
    }

    %Pleroma.Activity{
      data: data,
      actor: follower.ap_id
    }
  end

  def oauth_app_factory do
    %Pleroma.Web.OAuth.App{
      client_name: "Some client",
      redirect_uris: "https://example.com/callback",
      scopes: ["read", "write", "follow", "push"],
      website: "https://example.com",
      client_id: Ecto.UUID.generate(),
      client_secret: "aaa;/&bbb"
    }
  end

  def instance_factory do
    %Pleroma.Instances.Instance{
      host: "domain.com",
      unreachable_since: nil
    }
  end

  def oauth_token_factory do
    oauth_app = insert(:oauth_app)

    %Pleroma.Web.OAuth.Token{
      token: :crypto.strong_rand_bytes(32) |> Base.url_encode64(),
      scopes: ["read"],
      refresh_token: :crypto.strong_rand_bytes(32) |> Base.url_encode64(),
      user: build(:user),
      app_id: oauth_app.id,
      valid_until: NaiveDateTime.add(NaiveDateTime.utc_now(), 60 * 10)
    }
  end

  def oauth_authorization_factory do
    %Pleroma.Web.OAuth.Authorization{
      token: :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false),
      scopes: ["read", "write", "follow", "push"],
      valid_until: NaiveDateTime.add(NaiveDateTime.utc_now(), 60 * 10),
      user: build(:user),
      app: build(:oauth_app)
    }
  end

  def push_subscription_factory do
    %Pleroma.Web.Push.Subscription{
      user: build(:user),
      token: build(:oauth_token),
      endpoint: "https://example.com/example/1234",
      key_auth: "8eDyX_uCN0XRhSbY5hs7Hg==",
      key_p256dh:
        "BCIWgsnyXDv1VkhqL2P7YRBvdeuDnlwAPT2guNhdIoW3IP7GmHh1SMKPLxRf7x8vJy6ZFK3ol2ohgn_-0yP7QQA=",
      data: %{}
    }
  end

  def notification_factory do
    %Pleroma.Notification{
      user: build(:user)
    }
  end

  def scheduled_activity_factory do
    %Pleroma.ScheduledActivity{
      user: build(:user),
      scheduled_at: NaiveDateTime.add(NaiveDateTime.utc_now(), :timer.minutes(60), :millisecond),
      params: build(:note) |> Map.from_struct() |> Map.get(:data)
    }
  end

  def registration_factory do
    user = insert(:user)

    %Pleroma.Registration{
      user: user,
      provider: "twitter",
      uid: "171799000",
      info: %{
        "name" => "John Doe",
        "email" => "john@doe.com",
        "nickname" => "johndoe",
        "description" => "My bio"
      }
    }
  end

  def config_factory do
    %Pleroma.Web.AdminAPI.Config{
      key: sequence(:key, &"some_key_#{&1}"),
      group: "pleroma",
      value:
        sequence(
          :value,
          fn key ->
            :erlang.term_to_binary(%{another_key: "#{key}somevalue", another: "#{key}somevalue"})
          end
        )
    }
  end

  def marker_factory do
    %Pleroma.Marker{
      user: build(:user),
      timeline: "notifications",
      lock_version: 0,
      last_read_id: "1"
    }
  end
end
