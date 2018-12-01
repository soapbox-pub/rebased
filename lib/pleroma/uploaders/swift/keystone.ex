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
    |> Poison.decode!()
  end

  def get_token() do
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
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        body["access"]["token"]["id"]

      {:ok, %HTTPoison.Response{status_code: _}} ->
        ""
    end
  end

  def make_auth_body(username, password, tenant) do
    Poison.encode!(%{
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
