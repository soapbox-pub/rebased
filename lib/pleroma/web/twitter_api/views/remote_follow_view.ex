# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.TwitterAPI.RemoteFollowView do
  use Pleroma.Web, :view
  import Phoenix.HTML.Form

  def avatar_url(user), do: Pleroma.User.avatar_url(user)
end
