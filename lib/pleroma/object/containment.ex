# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Object.Containment do
  @moduledoc """
  This module contains some useful functions for containing objects to specific
  origins and determining those origins.  They previously lived in the
  ActivityPub `Transmogrifier` module.

  Object containment is an important step in validating remote objects to prevent
  spoofing, therefore removal of object containment functions is NOT recommended.
  """
  def get_actor(%{"actor" => actor}) when is_binary(actor) do
    actor
  end

  def get_actor(%{"actor" => actor}) when is_list(actor) do
    if is_binary(Enum.at(actor, 0)) do
      Enum.at(actor, 0)
    else
      Enum.find(actor, fn %{"type" => type} -> type in ["Person", "Service", "Application"] end)
      |> Map.get("id")
    end
  end

  def get_actor(%{"actor" => %{"id" => id}}) when is_bitstring(id) do
    id
  end

  def get_actor(%{"actor" => nil, "attributedTo" => actor}) when not is_nil(actor) do
    get_actor(%{"actor" => actor})
  end

  # TODO: We explicitly allow 'tag' URIs through, due to references to legacy OStatus
  # objects being present in the test suite environment.  Once these objects are
  # removed, please also remove this.
  if Mix.env() == :test do
    defp compare_uris(_, %URI{scheme: "tag"}), do: :ok
  end

  defp compare_uris(%URI{} = id_uri, %URI{} = other_uri) do
    if id_uri.host == other_uri.host do
      :ok
    else
      :error
    end
  end

  defp compare_uris(_, _), do: :error

  @doc """
  Checks that an imported AP object's actor matches the domain it came from.
  """
  def contain_origin(_id, %{"actor" => nil}), do: :error

  def contain_origin(id, %{"actor" => _actor} = params) do
    id_uri = URI.parse(id)
    actor_uri = URI.parse(get_actor(params))

    compare_uris(actor_uri, id_uri)
  end

  def contain_origin(id, %{"attributedTo" => actor} = params),
    do: contain_origin(id, Map.put(params, "actor", actor))

  def contain_origin(_id, _data), do: :error

  def contain_origin_from_id(id, %{"id" => other_id} = _params) when is_binary(other_id) do
    id_uri = URI.parse(id)
    other_uri = URI.parse(other_id)

    compare_uris(id_uri, other_uri)
  end

  def contain_origin_from_id(_id, _data), do: :error

  def contain_child(%{"object" => %{"id" => id, "attributedTo" => _} = object}),
    do: contain_origin(id, object)

  def contain_child(_), do: :ok
end
