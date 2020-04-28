# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.ObjectValidators.Types.SafeText do
  use Ecto.Type

  alias Pleroma.HTML

  def type, do: :string

  def cast(str) when is_binary(str) do
    {:ok, HTML.strip_tags(str)}
  end

  def cast(_), do: :error

  def dump(data) do
    {:ok, data}
  end

  def load(data) do
    {:ok, data}
  end
end
