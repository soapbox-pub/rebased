# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.MultiLanguage do
  defp template(:multi), do: Pleroma.Config.get([__MODULE__, :template])
  defp template(:single), do: Pleroma.Config.get([__MODULE__, :single_line_template])

  defp sep(:multi), do: Pleroma.Config.get([__MODULE__, :separator])
  defp sep(:single), do: Pleroma.Config.get([__MODULE__, :single_line_separator])

  def map_to_str(data, opts \\ []) do
    map_to_str_impl(data, if(opts[:multiline], do: :multi, else: :single))
  end

  defp map_to_str_impl(data, mode) do
    with ks <- Map.keys(data),
         [_, _ | _] <- ks,
         ks <- Enum.sort(ks) do
      template = template(mode)

      ks
      |> Enum.map(fn lang ->
        format_template(template, %{code: lang, content: data[lang]})
      end)
      |> Enum.join(sep(mode))
    else
      [lang] -> data[lang]
      _ -> ""
    end
  end

  def str_to_map(data) do
    %{"und" => data}
  end

  def format_template(template, %{code: code, content: content}) do
    template
    |> String.replace(
      ["{code}", "{content}"],
      fn
        "{code}" -> code
        "{content}" -> content
      end,
      global: true
    )
  end
end
