# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.ObjectValidator do
  @moduledoc """
  This module is responsible for validating an object (which can be an activity)
  and checking if it is both well formed and also compatible with our view of
  the system.
  """

  alias Pleroma.Object
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.ObjectValidators.Types
  alias Pleroma.Web.ActivityPub.ObjectValidators.ChatMessageValidator
  alias Pleroma.Web.ActivityPub.ObjectValidators.CreateChatMessageValidator
  alias Pleroma.Web.ActivityPub.ObjectValidators.LikeValidator

  @spec validate(map(), keyword()) :: {:ok, map(), keyword()} | {:error, any()}
  def validate(object, meta)

  def validate(%{"type" => "Like"} = object, meta) do
    with {:ok, object} <-
           object
           |> LikeValidator.cast_and_validate()
           |> Ecto.Changeset.apply_action(:insert) do
      object = stringify_keys(object)
      {:ok, object, meta}
    end
  end

  def validate(%{"type" => "ChatMessage"} = object, meta) do
    with {:ok, object} <-
           object
           |> ChatMessageValidator.cast_and_validate()
           |> Ecto.Changeset.apply_action(:insert) do
      object = stringify_keys(object)
      {:ok, object, meta}
    end
  end

  def validate(%{"type" => "Create", "object" => object} = create_activity, meta) do
    with {:ok, object_data} <- cast_and_apply(object),
         meta = Keyword.put(meta, :object_data, object_data |> stringify_keys),
         {:ok, create_activity} <-
           create_activity
           |> CreateChatMessageValidator.cast_and_validate(meta)
           |> Ecto.Changeset.apply_action(:insert) do
      create_activity = stringify_keys(create_activity)
      {:ok, create_activity, meta}
    end
  end

  def cast_and_apply(%{"type" => "ChatMessage"} = object) do
    ChatMessageValidator.cast_and_apply(object)
  end

  def cast_and_apply(o), do: {:error, {:validator_not_set, o}}

  def stringify_keys(%{__struct__: _} = object) do
    object
    |> Map.from_struct()
    |> stringify_keys
  end

  def stringify_keys(object) do
    object
    |> Map.new(fn {key, val} -> {to_string(key), val} end)
  end

  def fetch_actor(object) do
    with {:ok, actor} <- Types.ObjectID.cast(object["actor"]) do
      User.get_or_fetch_by_ap_id(actor)
    end
  end

  def fetch_actor_and_object(object) do
    fetch_actor(object)
    Object.normalize(object["object"])
    :ok
  end
end
