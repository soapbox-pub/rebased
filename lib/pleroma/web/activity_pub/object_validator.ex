# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.ObjectValidator do
  @moduledoc """
  This module is responsible for validating an object (which can be an activity)
  and checking if it is both well formed and also compatible with our view of
  the system.
  """

  alias Pleroma.User
  alias Pleroma.Object
  alias Pleroma.Web.ActivityPub.Utils

  def validate_id(object, meta) do
    with {_, true} <- {:id_presence, Map.has_key?(object, "id")} do
      {:ok, object, meta}
    else
      e -> {:error, e}
    end
  end

  def validate_actor(object, meta) do
    with {_, %User{}} <- {:actor_validation, User.get_cached_by_ap_id(object["actor"])} do
      {:ok, object, meta}
    else
      e -> {:error, e}
    end
  end

  def common_validations(object, meta) do
    with {_, {:ok, object, meta}} <- {:validate_id, validate_id(object, meta)},
      {_, {:ok, object, meta}} <- {:validate_actor, validate_actor(object, meta)} do
      {:ok, object, meta}
    else
      e -> {:error, e}
    end
  end

  @spec validate(map(), keyword()) :: {:ok, map(), keyword()} | {:error, any()}
  def validate(object, meta)

  def validate(%{"type" => "Like"} = object, meta) do
    with {:ok, object, meta} <- common_validations(object, meta),
         {_, %Object{} = liked_object} <- {:find_liked_object, Object.normalize(object["object"])},
         {_, nil} <- {:existing_like, Utils.get_existing_like(object["actor"], liked_object)} do
      {:ok, object, meta}
    else
      e -> {:error, e}
    end
  end

  def validate(object, meta) do
    common_validations(object, meta)
  end
end
