# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.AdminAPI.UserView do
  use Pleroma.Web, :view
  alias Pleroma.Web.AdminAPI

  def render(view, opts), do: AdminAPI.AccountView.render(view, opts)
end
