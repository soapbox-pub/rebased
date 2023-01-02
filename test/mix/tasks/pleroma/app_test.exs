# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Mix.Tasks.Pleroma.AppTest do
  use Pleroma.DataCase, async: true

  setup_all do
    Mix.shell(Mix.Shell.Process)

    on_exit(fn ->
      Mix.shell(Mix.Shell.IO)
    end)
  end

  describe "creates new app" do
    test "with default scopes" do
      name = "Some name"
      redirect = "https://example.com"
      Mix.Tasks.Pleroma.App.run(["create", "-n", name, "-r", redirect])

      assert_app(name, redirect, ["read", "write", "follow", "push"])
    end

    test "with custom scopes" do
      name = "Another name"
      redirect = "https://example.com"

      Mix.Tasks.Pleroma.App.run([
        "create",
        "-n",
        name,
        "-r",
        redirect,
        "-s",
        "read,write,follow,push,admin"
      ])

      assert_app(name, redirect, ["read", "write", "follow", "push", "admin"])
    end
  end

  test "with errors" do
    Mix.Tasks.Pleroma.App.run(["create"])
    {:mix_shell, :error, ["Creating failed:"]}
    {:mix_shell, :error, ["name: can't be blank"]}
    {:mix_shell, :error, ["redirect_uris: can't be blank"]}
  end

  defp assert_app(name, redirect, scopes) do
    app = Repo.get_by(Pleroma.Web.OAuth.App, client_name: name)

    assert_receive {:mix_shell, :info, [message]}
    assert message == "#{name} successfully created:"

    assert_receive {:mix_shell, :info, [message]}
    assert message == "App client_id: #{app.client_id}"

    assert_receive {:mix_shell, :info, [message]}
    assert message == "App client_secret: #{app.client_secret}"

    assert app.scopes == scopes
    assert app.redirect_uris == redirect
  end
end
