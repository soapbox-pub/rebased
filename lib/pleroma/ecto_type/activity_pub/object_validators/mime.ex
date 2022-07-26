# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.EctoType.ActivityPub.ObjectValidators.MIME do
  use Ecto.Type

  require Pleroma.Constants

  def type, do: :string

  def cast(mime) when is_binary(mime) do
    if mime =~ Pleroma.Constants.mime_regex() do
      {:ok, mime}
    else
      {:ok, "application/octet-stream"}
    end
  end

  def cast(_), do: :error

  def dump(data), do: {:ok, data}

  def load(data), do: {:ok, data}
end
