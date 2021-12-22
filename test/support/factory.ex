# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Factory do
  use ExMachina.Ecto, repo: Pleroma.Repo

  require Pleroma.Constants

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

  def user_factory(attrs \\ %{}) do
    user = %User{
      name: sequence(:name, &"Test テスト User #{&1}"),
      email: sequence(:email, &"user#{&1}@example.com"),
      nickname: sequence(:nickname, &"nick#{&1}"),
      password_hash: Pleroma.Password.Pbkdf2.hash_pwd_salt("test"),
      bio: sequence(:bio, &"Tester Number #{&1}"),
      is_discoverable: true,
      last_digest_emailed_at: NaiveDateTime.utc_now(),
      last_refreshed_at: NaiveDateTime.utc_now(),
      notification_settings: %Pleroma.User.NotificationSetting{},
      multi_factor_authentication_settings: %Pleroma.MFA.Settings{},
      ap_enabled: true
    }

    urls =
      if attrs[:local] == false do
        base_domain = attrs[:domain] || Enum.random(["domain1.com", "domain2.com", "domain3.com"])

        ap_id = "https://#{base_domain}/users/#{user.nickname}"

        %{
          ap_id: ap_id,
          follower_address: ap_id <> "/followers",
          following_address: ap_id <> "/following",
          featured_address: ap_id <> "/collections/featured"
        }
      else
        %{
          ap_id: User.ap_id(user),
          follower_address: User.ap_followers(user),
          following_address: User.ap_following(user),
          featured_address: User.ap_featured_collection(user)
        }
      end

    attrs = Map.delete(attrs, :domain)

    user
    |> Map.put(:raw_bio, user.bio)
    |> Map.merge(urls)
    |> merge_attributes(attrs)
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
      "source" => text,
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

  def attachment_note_factory(attrs \\ %{}) do
    user = attrs[:user] || insert(:user)
    {length, attrs} = Map.pop(attrs, :length, 1)

    data = %{
      "attachment" =>
        Stream.repeatedly(fn -> attachment_data(user.ap_id, attrs[:href]) end)
        |> Enum.take(length)
    }

    build(:note, Map.put(attrs, :data, data))
  end

  defp attachment_data(ap_id, href) do
    href = href || sequence(:href, &"#{Pleroma.Web.Endpoint.url()}/media/#{&1}.jpg")

    %{
      "url" => [
        %{
          "href" => href,
          "type" => "Link",
          "mediaType" => "image/jpeg"
        }
      ],
      "name" => "some name",
      "type" => "Document",
      "actor" => ap_id,
      "mediaType" => "image/jpeg"
    }
  end

  def followers_only_note_factory(attrs \\ %{}) do
    %Pleroma.Object{data: data} = note_factory(attrs)
    %Pleroma.Object{data: Map.merge(data, %{"to" => [data["actor"] <> "/followers"]})}
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
    %Pleroma.Object{data: data} = note_factory()
    %Pleroma.Object{data: Map.merge(data, %{"type" => "Article"})}
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

  def question_factory(attrs \\ %{}) do
    user = attrs[:user] || insert(:user)

    data = %{
      "id" => Pleroma.Web.ActivityPub.Utils.generate_object_id(),
      "type" => "Question",
      "actor" => user.ap_id,
      "attributedTo" => user.ap_id,
      "attachment" => [],
      "to" => ["https://www.w3.org/ns/activitystreams#Public"],
      "cc" => [user.follower_address],
      "context" => Pleroma.Web.ActivityPub.Utils.generate_context_id(),
      "closed" => DateTime.utc_now() |> DateTime.add(86_400) |> DateTime.to_iso8601(),
      "oneOf" => [
        %{
          "type" => "Note",
          "name" => "chocolate",
          "replies" => %{"totalItems" => 0, "type" => "Collection"}
        },
        %{
          "type" => "Note",
          "name" => "vanilla",
          "replies" => %{"totalItems" => 0, "type" => "Collection"}
        }
      ]
    }

    %Pleroma.Object{
      data: merge_attributes(data, Map.get(attrs, :data, %{}))
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

  def add_activity_factory(attrs \\ %{}) do
    featured_collection_activity(attrs, "Add")
  end

  def remove_activity_factor(attrs \\ %{}) do
    featured_collection_activity(attrs, "Remove")
  end

  defp featured_collection_activity(attrs, type) do
    user = attrs[:user] || insert(:user)
    note = attrs[:note] || insert(:note, user: user)

    data_attrs =
      attrs
      |> Map.get(:data_attrs, %{})
      |> Map.put(:type, type)

    attrs = Map.drop(attrs, [:user, :note, :data_attrs])

    data =
      %{
        "id" => Pleroma.Web.ActivityPub.Utils.generate_activity_id(),
        "target" => user.featured_address,
        "object" => note.data["object"],
        "actor" => note.data["actor"],
        "type" => "Add",
        "to" => [Pleroma.Constants.as_public()],
        "cc" => [user.follower_address]
      }
      |> Map.merge(data_attrs)

    %Pleroma.Activity{
      data: data,
      actor: data["actor"],
      recipients: data["to"]
    }
    |> Map.merge(attrs)
  end

  def followers_only_note_activity_factory(attrs \\ %{}) do
    user = attrs[:user] || insert(:user)
    note = insert(:followers_only_note, user: user)

    data_attrs = attrs[:data_attrs] || %{}
    attrs = Map.drop(attrs, [:user, :note, :data_attrs])

    data =
      %{
        "id" => Pleroma.Web.ActivityPub.Utils.generate_activity_id(),
        "type" => "Create",
        "actor" => note.data["actor"],
        "to" => note.data["to"],
        "object" => note.data,
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
    object = Object.normalize(note_activity, fetch: false)
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

  def report_activity_factory(attrs \\ %{}) do
    user = attrs[:user] || insert(:user)
    activity = attrs[:activity] || insert(:note_activity)
    state = attrs[:state] || "open"

    data = %{
      "id" => Pleroma.Web.ActivityPub.Utils.generate_activity_id(),
      "actor" => user.ap_id,
      "type" => "Flag",
      "object" => [activity.actor, activity.data["id"]],
      "published" => DateTime.utc_now() |> DateTime.to_iso8601(),
      "to" => [],
      "cc" => [activity.actor],
      "context" => activity.data["context"],
      "state" => state
    }

    %Pleroma.Activity{
      data: data,
      actor: data["actor"],
      recipients: data["to"] ++ data["cc"]
    }
  end

  def question_activity_factory(attrs \\ %{}) do
    user = attrs[:user] || insert(:user)
    question = attrs[:question] || insert(:question, user: user)

    data_attrs = attrs[:data_attrs] || %{}
    attrs = Map.drop(attrs, [:user, :question, :data_attrs])

    data =
      %{
        "id" => Pleroma.Web.ActivityPub.Utils.generate_activity_id(),
        "type" => "Create",
        "actor" => question.data["actor"],
        "to" => question.data["to"],
        "object" => question.data["id"],
        "published" => DateTime.utc_now() |> DateTime.to_iso8601(),
        "context" => question.data["context"]
      }
      |> Map.merge(data_attrs)

    %Pleroma.Activity{
      data: data,
      actor: data["actor"],
      recipients: data["to"]
    }
    |> Map.merge(attrs)
  end

  def oauth_app_factory do
    %Pleroma.Web.OAuth.App{
      client_name: sequence(:client_name, &"Some client #{&1}"),
      redirect_uris: "https://example.com/callback",
      scopes: ["read", "write", "follow", "push", "admin"],
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

  def oauth_token_factory(attrs \\ %{}) do
    scopes = Map.get(attrs, :scopes, ["read"])
    oauth_app = Map.get_lazy(attrs, :app, fn -> insert(:oauth_app, scopes: scopes) end)
    user = Map.get_lazy(attrs, :user, fn -> build(:user) end)

    valid_until =
      Map.get(attrs, :valid_until, NaiveDateTime.add(NaiveDateTime.utc_now(), 60 * 10))

    %Pleroma.Web.OAuth.Token{
      token: :crypto.strong_rand_bytes(32) |> Base.url_encode64(),
      refresh_token: :crypto.strong_rand_bytes(32) |> Base.url_encode64(),
      scopes: scopes,
      user: user,
      app: oauth_app,
      valid_until: valid_until
    }
  end

  def oauth_admin_token_factory(attrs \\ %{}) do
    user = Map.get_lazy(attrs, :user, fn -> build(:user, is_admin: true) end)

    scopes =
      attrs
      |> Map.get(:scopes, ["admin"])
      |> Kernel.++(["admin"])
      |> Enum.uniq()

    attrs = Map.merge(attrs, %{user: user, scopes: scopes})
    oauth_token_factory(attrs)
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

  def config_factory(attrs \\ %{}) do
    %Pleroma.ConfigDB{
      key: sequence(:key, &String.to_atom("some_key_#{&1}")),
      group: :pleroma,
      value:
        sequence(
          :value,
          &%{another_key: "#{&1}somevalue", another: "#{&1}somevalue"}
        )
    }
    |> merge_attributes(attrs)
  end

  def marker_factory do
    %Pleroma.Marker{
      user: build(:user),
      timeline: "notifications",
      lock_version: 0,
      last_read_id: "1"
    }
  end

  def mfa_token_factory do
    %Pleroma.MFA.Token{
      token: :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false),
      authorization: build(:oauth_authorization),
      valid_until: NaiveDateTime.add(NaiveDateTime.utc_now(), 60 * 10),
      user: build(:user)
    }
  end

  def filter_factory do
    %Pleroma.Filter{
      user: build(:user),
      filter_id: sequence(:filter_id, & &1),
      phrase: "cofe",
      context: ["home"]
    }
  end
end
