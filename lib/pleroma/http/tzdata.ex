# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.HTTP.Tzdata do
  @moduledoc false

  @behaviour Tzdata.HTTPClient

  alias Pleroma.HTTP

  @impl true
  def get(url, headers, options) do
    options = Keyword.put_new(options, :pool, :default)

    with {:ok, %Tesla.Env{} = env} <- HTTP.get(url, headers, options) do
      {:ok, {env.status, env.headers, env.body}}
    end
  end

  @impl true
  def head(url, headers, options) do
    options = Keyword.put_new(options, :pool, :default)

    with {:ok, %Tesla.Env{} = env} <- HTTP.head(url, headers, options) do
      {:ok, {env.status, env.headers}}
    end
  end
end
