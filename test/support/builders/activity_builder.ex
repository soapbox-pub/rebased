defmodule Pleroma.Builders.ActivityBuilder do
  alias Pleroma.Builders.UserBuilder
  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Pleroma.User

  def public_and_non_public do
    {:ok, user} = UserBuilder.insert
    public = %{
      "id" => 1,
      "actor" => user.ap_id,
      "to" => ["https://www.w3.org/ns/activitystreams#Public"],
      "object" => %{
        "type" => "Note",
        "content" => "test"
      }
    }

    non_public = %{
      "id" => 2,
      "actor" => user.ap_id,
      "to" => [],
      "object" => %{
        "type" => "Note",
        "content" => "test"
      }
    }

    {:ok, public} = ActivityPub.insert(public)
    {:ok, non_public} = ActivityPub.insert(non_public)

    %{
      public: public,
      non_public: non_public,
      user: user
    }
  end
end
