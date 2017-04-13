defmodule Pleroma.Factory do
  use ExMachina.Ecto, repo: Pleroma.Repo

  def user_factory do
    user = %Pleroma.User{
      name: sequence(:name, &"Test User #{&1}"),
      email: sequence(:email, &"user#{&1}@example.com"),
      nickname: sequence(:nickname, &"nick#{&1}"),
      password_hash: Comeonin.Pbkdf2.hashpwsalt("test"),
      bio: sequence(:bio, &"Tester Number #{&1}"),
    }
    %{ user | ap_id: Pleroma.User.ap_id(user) }
  end

  def note_factory do
    text = sequence(:text, &"This is note #{&1}")

    user = insert(:user)
    data = %{
      "type" => "Note",
      "content" => text,
      "id" => Pleroma.Web.ActivityPub.ActivityPub.generate_object_id,
      "actor" => user.ap_id,
      "to" => ["https://www.w3.org/ns/activitystreams#Public"],
      "published_at" => DateTime.utc_now() |> DateTime.to_iso8601
    }

    %Pleroma.Object{
      data: data
    }
  end

  def note_activity_factory do
    note = insert(:note)
    data = %{
      "id" => Pleroma.Web.ActivityPub.ActivityPub.generate_activity_id,
      "type" => "Create",
      "actor" => note.data["actor"],
      "to" => note.data["to"],
      "object" => note.data,
      "published_at" => DateTime.utc_now() |> DateTime.to_iso8601
    }

    %Pleroma.Activity{
      data: data
    }
  end

  def like_activity_factory do
    note_activity = insert(:note_activity)
    user = insert(:user)

    data = %{
      "id" => Pleroma.Web.ActivityPub.ActivityPub.generate_activity_id,
      "actor" => user.ap_id,
      "type" => "Like",
      "object" => note_activity.data["object"]["id"],
      "published_at" => DateTime.utc_now() |> DateTime.to_iso8601
    }

    %Pleroma.Activity{
      data: data
    }
  end
end
