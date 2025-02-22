# Pleroma: A lightweight social networking server
# Copyright © 2017-2023 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.EctoType.ActivityPub.ObjectValidators.LanguageCode do
  use Ecto.Type

  def type, do: :string

  def cast(language) when is_binary(language) do
    if good_locale_code?(language) do
      {:ok, language}
    else
      {:error, :invalid_language}
    end
  end

  def cast(_), do: :error

  def dump(data), do: {:ok, data}

  def load(data), do: {:ok, data}

  def good_locale_code?(code) when is_binary(code), do: code =~ ~r<^[a-zA-Z0-9\-]+\z$>

  def good_locale_code?(_code), do: false
end
