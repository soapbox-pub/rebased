# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.AdminAPI.InviteView do
  use Pleroma.Web, :view

  def render("index.json", %{invites: invites}) do
    %{
      invites: render_many(invites, __MODULE__, "show.json", as: :invite)
    }
  end

  def render("show.json", %{invite: invite}) do
    %{
      "id" => invite.id,
      "token" => invite.token,
      "used" => invite.used,
      "expires_at" => invite.expires_at,
      "uses" => invite.uses,
      "max_use" => invite.max_use,
      "invite_type" => invite.invite_type
    }
  end
end
