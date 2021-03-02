# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.HTTP.ExAws do
  @moduledoc false

  @behaviour ExAws.Request.HttpClient

  alias Pleroma.HTTP

  @impl true
  def request(method, url, body \\ "", headers \\ [], http_opts \\ []) do
    http_opts = Keyword.put_new(http_opts, :pool, :upload)

    case HTTP.request(method, url, body, headers, http_opts) do
      {:ok, env} ->
        {:ok, %{status_code: env.status, headers: env.headers, body: env.body}}

      {:error, reason} ->
        {:error, %{reason: reason}}
    end
  end
end
