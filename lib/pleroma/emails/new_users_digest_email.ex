# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Emails.NewUsersDigestEmail do
  use Phoenix.Swoosh, view: Pleroma.Web.EmailView, layout: {Pleroma.Web.LayoutView, :email_styled}

  defp instance_notify_email do
    Pleroma.Config.get([:instance, :notify_email]) || Pleroma.Config.get([:instance, :email])
  end

  def new_users(to, users_and_statuses) do
    instance_name = Pleroma.Config.get([:instance, :name])
    styling = Pleroma.Config.get([Pleroma.Emails.UserEmail, :styling])

    logo_url =
      Pleroma.Web.Endpoint.url() <>
        Pleroma.Config.get([:frontend_configurations, :pleroma_fe, :logo])

    new()
    |> to({to.name, to.email})
    |> from({instance_name, instance_notify_email()})
    |> subject("#{instance_name} New Users")
    |> render_body("new_users_digest.html", %{
      title: "New Users",
      users_and_statuses: users_and_statuses,
      instance: instance_name,
      styling: styling,
      logo_url: logo_url
    })
  end
end
