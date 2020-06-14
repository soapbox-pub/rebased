# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MediaProxy.Invalidation.Script do
  @moduledoc false

  @behaviour Pleroma.Web.MediaProxy.Invalidation

  require Logger

  @impl Pleroma.Web.MediaProxy.Invalidation
  def purge(urls, opts) do
    args =
      urls
      |> List.wrap()
      |> Enum.uniq()
      |> Enum.join(" ")

    opts
    |> Keyword.get(:script_path, nil)
    |> do_purge([args])
    |> handle_result(urls)
  end

  defp do_purge(script_path, args) when is_binary(script_path) do
    path = Path.expand(script_path)
    Logger.debug("Running cache purge: #{inspect(args)}, #{inspect(path)}")
    System.cmd(path, args)
  rescue
    error -> error
  end

  defp do_purge(_, _), do: {:error, "not found script path"}

  defp handle_result({_result, 0}, urls), do: {:ok, urls}
  defp handle_result({:error, error}, urls), do: handle_result(error, urls)

  defp handle_result(error, _) do
    Logger.error("Error while cache purge: #{inspect(error)}")
    {:error, inspect(error)}
  end
end
