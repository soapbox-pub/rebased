defmodule Pleroma.Web.OStatus.UserRepresenter do
  alias Pleroma.User
  def to_simple_form(user) do
    ap_id = to_charlist(user.ap_id)
    nickname = to_charlist(user.nickname)
    avatar_url = to_charlist(User.avatar_url(user))
    [
      { :id, [ap_id] },
      { :"activity:object", ['http://activitystrea.ms/schema/1.0/person'] },
      { :uri, [ap_id] },
      { :name, [nickname] },
      { :link, [rel: 'avatar', href: avatar_url], []}
    ]
  end
end
