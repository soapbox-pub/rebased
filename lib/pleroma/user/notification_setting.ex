# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.User.NotificationSetting do
  use Ecto.Schema
  import Ecto.Changeset

  @derive Jason.Encoder
  @primary_key false

  embedded_schema do
    field(:followers, :boolean, default: true)
    field(:follows, :boolean, default: true)
    field(:non_follows, :boolean, default: true)
    field(:non_followers, :boolean, default: true)
    field(:privacy_option, :boolean, default: false)
  end

  def changeset(schema, params) do
    schema
    |> cast(prepare_attrs(params), [
      :followers,
      :follows,
      :non_follows,
      :non_followers,
      :privacy_option
    ])
  end

  defp prepare_attrs(params) do
    Enum.reduce(params, %{}, fn
      {k, v}, acc when is_binary(v) ->
        Map.put(acc, k, String.downcase(v))

      {k, v}, acc ->
        Map.put(acc, k, v)
    end)
  end
end
