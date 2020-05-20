# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MediaProxy.Invalidation.Script do
  @moduledoc false

  @behaviour Pleroma.Web.MediaProxy.Invalidation

  require Logger

  @impl Pleroma.Web.MediaProxy.Invalidation
  def purge(urls, %{script_path: script_path} = _options) do
    args =
      urls
      |> List.wrap()
      |> Enum.uniq()
      |> Enum.join(" ")

    path = Path.expand(script_path)

    Logger.debug("Running cache purge: #{inspect(urls)}, #{path}")

    case do_purge(path, [args]) do
      {result, exit_status} when exit_status > 0 ->
        Logger.error("Error while cache purge: #{inspect(result)}")
        {:error, inspect(result)}

      _ ->
        {:ok, "success"}
    end
  end

  def purge(_, _), do: {:error, "not found script path"}

  defp do_purge(path, args) do
    System.cmd(path, args)
  rescue
    error -> {inspect(error), 1}
  end
end
