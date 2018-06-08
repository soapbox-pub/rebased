defmodule Pleroma.Web.ActivityPub.MRF.RejectNonPublic do
  alias Pleroma.User
  @behaviour Pleroma.Web.ActivityPub.MRF

  def filter(object) do
    if object["type"] == "Create" do
      user = User.get_by_ap_id(object["actor"])
      public = "https://www.w3.org/ns/activitystreams#Public"

      #Determine visibility
      visibility =
        cond do
          #Public
          public in object["to"] -> "p"
          #Unlisted
          public in object["cc"] -> "u"
          #Followers-only
          user.follower_address in object["to"] -> "f"
          #Direct
          true -> "d"
        end

      case visibility do
        "p" -> {:ok, object}
        "u" -> {:ok, object}
        _ -> {:reject, nil}
      end
    else
      {:ok, object}
    end
  end

end
