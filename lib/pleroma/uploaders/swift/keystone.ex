# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Uploaders.Swift.Keystone do
  use HTTPoison.Base

  def process_url(url) do
    Enum.join(
      [Pleroma.Config.get!([Pleroma.Uploaders.Swift, :auth_url]), url],
      "/"
    )
  end

  def process_response_body(body) do
    body
    |> Jason.decode!()
  end

  def get_token do
    settings = Pleroma.Config.get(Pleroma.Uploaders.Swift)
    username = Keyword.fetch!(settings, :username)
    password = Keyword.fetch!(settings, :password)
    tenant_id = Keyword.fetch!(settings, :tenant_id)

    case post(
           "/tokens",
           make_auth_body(username, password, tenant_id),
           ["Content-Type": "application/json"],
           hackney: [:insecure]
         ) do
      {:ok, %Tesla.Env{status: 200, body: body}} ->
        body["access"]["token"]["id"]

      {:ok, %Tesla.Env{status: _}} ->
        ""
    end
  end

  def make_auth_body(username, password, tenant) do
    Jason.encode!(%{
      :auth => %{
        :passwordCredentials => %{
          :username => username,
          :password => password
        },
        :tenantId => tenant
      }
    })
  end
end
