# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.User.WelcomeEmailTest do
  use Pleroma.DataCase

  alias Pleroma.Config
  alias Pleroma.Tests.ObanHelpers
  alias Pleroma.User.WelcomeEmail

  import Pleroma.Factory
  import Swoosh.TestAssertions

  setup do: clear_config([:welcome])

  describe "send_email/1" do
    test "send a welcome email" do
      user = insert(:user, name: "Jimm")

      clear_config([:welcome, :email, :enabled], true)
      clear_config([:welcome, :email, :sender], "welcome@pleroma.app")

      clear_config(
        [:welcome, :email, :subject],
        "Hello, welcome to pleroma: <%= instance_name %>"
      )

      clear_config(
        [:welcome, :email, :html],
        "<h1>Hello <%= user.name %>.</h1> <p>Welcome to <%= instance_name %></p>"
      )

      instance_name = Config.get([:instance, :name])

      {:ok, _job} = WelcomeEmail.send_email(user)

      ObanHelpers.perform_all()

      assert_email_sent(
        from: {instance_name, "welcome@pleroma.app"},
        to: {user.name, user.email},
        subject: "Hello, welcome to pleroma: #{instance_name}",
        html_body: "<h1>Hello #{user.name}.</h1> <p>Welcome to #{instance_name}</p>"
      )

      clear_config([:welcome, :email, :sender], {"Pleroma App", "welcome@pleroma.app"})

      {:ok, _job} = WelcomeEmail.send_email(user)

      ObanHelpers.perform_all()

      assert_email_sent(
        from: {"Pleroma App", "welcome@pleroma.app"},
        to: {user.name, user.email},
        subject: "Hello, welcome to pleroma: #{instance_name}",
        html_body: "<h1>Hello #{user.name}.</h1> <p>Welcome to #{instance_name}</p>"
      )
    end
  end
end
