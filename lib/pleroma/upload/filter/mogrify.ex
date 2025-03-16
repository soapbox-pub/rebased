# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Upload.Filter.Mogrify do
  @behaviour Pleroma.Upload.Filter

  @type conversion :: action :: String.t() | {action :: String.t(), opts :: String.t()}
  @type conversions :: conversion() | [conversion()]

  @config_impl Application.compile_env(:pleroma, [__MODULE__, :config_impl], Pleroma.Config)
  @mogrify_impl Application.compile_env(
                  :pleroma,
                  [__MODULE__, :mogrify_impl],
                  Pleroma.MogrifyWrapper
                )

  def filter(%Pleroma.Upload{tempfile: file, content_type: "image" <> _}) do
    try do
      do_filter(file, @config_impl.get!([__MODULE__, :args]))
      {:ok, :filtered}
    rescue
      e in ErlangError ->
        {:error, "#{__MODULE__}: #{inspect(e)}"}
    end
  end

  def filter(_), do: {:ok, :noop}

  def do_filter(file, filters) do
    file
    |> @mogrify_impl.open()
    |> mogrify_filter(filters)
    |> @mogrify_impl.save(in_place: true)
  end

  defp mogrify_filter(mogrify, nil), do: mogrify

  defp mogrify_filter(mogrify, [filter | rest]) do
    mogrify
    |> mogrify_filter(filter)
    |> mogrify_filter(rest)
  end

  defp mogrify_filter(mogrify, []), do: mogrify

  defp mogrify_filter(mogrify, {action, options}) do
    @mogrify_impl.custom(mogrify, action, options)
  end

  defp mogrify_filter(mogrify, action) when is_binary(action) do
    @mogrify_impl.custom(mogrify, action)
  end
end
