# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Mix.Tasks.Pleroma.App do
  @moduledoc File.read!("docs/administration/CLI_tasks/oauth_app.md")
  use Mix.Task

  import Mix.Pleroma

  @shortdoc "Creates trusted OAuth App"

  def run(["create" | options]) do
    start_pleroma()

    {opts, _} =
      OptionParser.parse!(options,
        strict: [name: :string, redirect_uri: :string, scopes: :string],
        aliases: [n: :name, r: :redirect_uri, s: :scopes]
      )

    scopes =
      if opts[:scopes] do
        String.split(opts[:scopes], ",")
      else
        ["read", "write", "follow", "push"]
      end

    params = %{
      client_name: opts[:name],
      redirect_uris: opts[:redirect_uri],
      trusted: true,
      scopes: scopes
    }

    with {:ok, app} <- Pleroma.Web.OAuth.App.create(params) do
      shell_info("#{app.client_name} successfully created:")
      shell_info("App client_id: " <> app.client_id)
      shell_info("App client_secret: " <> app.client_secret)
    else
      {:error, changeset} ->
        shell_error("Creating failed:")

        Enum.each(Pleroma.Web.OAuth.App.errors(changeset), fn {key, error} ->
          shell_error("#{key}: #{error}")
        end)
    end
  end
end
