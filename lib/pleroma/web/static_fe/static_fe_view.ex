# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.StaticFE.StaticFEView do
  use Pleroma.Web, :view

  alias Pleroma.User
  alias Pleroma.Web.MediaProxy
  alias Pleroma.Formatter
  alias Pleroma.Web.Router.Helpers

  import Phoenix.HTML

  def emoji_for_user(%User{} = user) do
    (user.source_data["tag"] || [])
    |> Enum.filter(fn %{"type" => t} -> t == "Emoji" end)
    |> Enum.map(fn %{"icon" => %{"url" => url}, "name" => name} ->
      {String.trim(name, ":"), url}
    end)
  end
end
