# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MediaProxy.Invalidation do
  @moduledoc false

  @callback purge(list(String.t()), map()) :: {:ok, String.t()} | {:error, String.t()}

  alias Pleroma.Config

  @spec purge(list(String.t())) :: {:ok, String.t()} | {:error, String.t()}
  def purge(urls) do
    [:media_proxy, :invalidation, :enabled]
    |> Config.get()
    |> do_purge(urls)
  end

  defp do_purge(true, urls) do
    provider = Config.get([:media_proxy, :invalidation, :provider])
    options = Config.get(provider)
    provider.purge(urls, options)
  end

  defp do_purge(_, _), do: :ok
end
