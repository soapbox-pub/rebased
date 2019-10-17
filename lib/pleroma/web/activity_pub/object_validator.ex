# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.ObjectValidator do
  @moduledoc """
  This module is responsible for validating an object (which can be an activity)
  and checking if it is both well formed and also compatible with our view of
  the system.
  """

  alias Pleroma.Web.ActivityPub.ObjectValidators.LikeValidator

  @spec validate(map(), keyword()) :: {:ok, map(), keyword()} | {:error, any()}
  def validate(object, meta)

  def validate(%{"type" => "Like"} = object, meta) do
    with {_, %{valid?: true, changes: object}} <-
           {:validate_object, LikeValidator.cast_and_validate(object)} do
      object = stringify_keys(object)
      {:ok, object, meta}
    else
      e -> {:error, e}
    end
  end

  defp stringify_keys(object) do
    object
    |> Enum.map(fn {key, val} -> {to_string(key), val} end)
    |> Enum.into(%{})
  end
end
