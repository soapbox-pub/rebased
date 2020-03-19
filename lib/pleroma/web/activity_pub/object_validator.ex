# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.ObjectValidator do
  @moduledoc """
  This module is responsible for validating an object (which can be an activity)
  and checking if it is both well formed and also compatible with our view of
  the system.
  """

  alias Pleroma.Object
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.ObjectValidators.LikeValidator

  @spec validate(map(), keyword()) :: {:ok, map(), keyword()} | {:error, any()}
  def validate(object, meta)

  def validate(%{"type" => "Like"} = object, meta) do
    with {:ok, object} <-
           object |> LikeValidator.cast_and_validate() |> Ecto.Changeset.apply_action(:insert) do
      object = stringify_keys(object |> Map.from_struct())
      {:ok, object, meta}
    end
  end

  def stringify_keys(object) do
    object
    |> Enum.map(fn {key, val} -> {to_string(key), val} end)
    |> Enum.into(%{})
  end

  def fetch_actor_and_object(object) do
    User.get_or_fetch_by_ap_id(object["actor"])
    Object.normalize(object["object"])
    :ok
  end
end
