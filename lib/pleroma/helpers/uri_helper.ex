# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Helpers.UriHelper do
  def modify_uri_params(uri, overridden_params, deleted_params \\ []) do
    uri = URI.parse(uri)

    existing_params = URI.query_decoder(uri.query || "") |> Map.new()
    overridden_params = Map.new(overridden_params, fn {k, v} -> {to_string(k), v} end)
    deleted_params = Enum.map(deleted_params, &to_string/1)

    updated_params =
      existing_params
      |> Map.merge(overridden_params)
      |> Map.drop(deleted_params)

    uri
    |> Map.put(:query, URI.encode_query(updated_params))
    |> URI.to_string()
    |> String.replace_suffix("?", "")
  end

  def maybe_add_base("/" <> uri, base), do: Path.join([base, uri])
  def maybe_add_base(uri, _base), do: uri
end
