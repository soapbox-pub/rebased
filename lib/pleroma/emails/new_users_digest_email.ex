# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Emails.NewUsersDigestEmail do
  use Phoenix.Swoosh, view: Pleroma.Web.EmailView, layout: {Pleroma.Web.LayoutView, :email_styled}

  defp instance_notify_email do
    Pleroma.Config.get([:instance, :notify_email]) || Pleroma.Config.get([:instance, :email])
  end

  def new_users(to, users_and_statuses) do
    instance_name = Pleroma.Config.get([:instance, :name])
    styling = Pleroma.Config.get([Pleroma.Emails.UserEmail, :styling])
    logo = Pleroma.Config.get([Pleroma.Emails.UserEmail, :logo])

    logo_path =
      if is_nil(logo) do
        Path.join(:code.priv_dir(:pleroma), "static/static/logo.png")
      else
        Path.join(Pleroma.Config.get([:instance, :static_dir]), logo)
      end

    new()
    |> to({to.name, to.email})
    |> from({instance_name, instance_notify_email()})
    |> subject("#{instance_name} New Users")
    |> render_body("new_users_digest.html", %{
      title: "New Users",
      users_and_statuses: users_and_statuses,
      instance: instance_name,
      styling: styling
    })
    |> attachment(Swoosh.Attachment.new(logo_path, filename: "logo.png", type: :inline))
  end
end
