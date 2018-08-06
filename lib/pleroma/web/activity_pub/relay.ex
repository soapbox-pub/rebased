defmodule Pleroma.Web.ActivityPub.Relay do
  alias Pleroma.User

  def get_actor do
    User.get_or_create_instance_user()
  end
end
