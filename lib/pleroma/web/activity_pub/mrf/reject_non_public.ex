defmodule Pleroma.Web.ActivityPub.MRF.RejectNonPublic do
  alias Pleroma.User
  @behaviour Pleroma.Web.ActivityPub.MRF

  @impl true
  def filter(object) do
    if object["type"] == "Create" do
      user = User.get_by_ap_id(object["actor"])
      public = "https://www.w3.org/ns/activitystreams#Public"

      # Determine visibility
      visibility =
        cond do
          public in object["to"] -> "public"
          public in object["cc"] -> "unlisted"
          user.follower_address in object["to"] -> "followers"
          true -> "direct"
        end

      {flag, object_out} =
        case visibility do
          "public" -> {:ok, object}
          "unlisted" -> {:ok, object}
          _ -> {:reject, nil}
        end

      {flag, object_out}
    else
      {:ok, object}
    end
  end
end
