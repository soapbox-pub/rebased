defmodule Pleroma.Web.OStatus.UserRepresenter do
  alias Pleroma.User
  def to_tuple(user, wrapper \\ :author) do
    {
      wrapper, [
        { :id, user.ap_id },
        { :"activity:object", "http://activitystrea.ms/schema/1.0/person" },
        { :uri, user.ap_id },
        { :name, user.nickname },
        { :link, %{rel: "avatar", href: User.avatar_url(user)}}
      ]
    }
  end
end
