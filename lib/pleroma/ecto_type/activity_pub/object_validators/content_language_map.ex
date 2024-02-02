# Pleroma: A lightweight social networking server
# Copyright © 2017-2023 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.EctoType.ActivityPub.ObjectValidators.ContentLanguageMap do
  use Ecto.Type

  import Pleroma.EctoType.ActivityPub.ObjectValidators.LanguageCode,
    only: [good_locale_code?: 1]

  def type, do: :map

  def cast(%{} = object) do
    with {status, %{} = data} when status in [:modified, :ok] <- validate_map(object) do
      {:ok, data}
    else
      {_, nil} -> {:ok, nil}
      {:error, _} -> :error
    end
  end

  def cast(_), do: :error

  def dump(data), do: {:ok, data}

  def load(data), do: {:ok, data}

  defp validate_map(%{} = object) do
    {status, data} =
      object
      |> Enum.reduce({:ok, %{}}, fn
        {lang, value}, {status, acc} when is_binary(lang) and is_binary(value) ->
          if good_locale_code?(lang) do
            {status, Map.put(acc, lang, value)}
          else
            {:modified, acc}
          end

        _, {_status, acc} ->
          {:modified, acc}
      end)

    if data == %{} do
      {status, nil}
    else
      {status, data}
    end
  end
end
