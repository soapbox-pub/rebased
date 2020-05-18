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
  alias Pleroma.Web.ActivityPub.ObjectValidators.AnnounceValidator
  alias Pleroma.Web.ActivityPub.ObjectValidators.DeleteValidator
  alias Pleroma.Web.ActivityPub.ObjectValidators.EmojiReactValidator
  alias Pleroma.Web.ActivityPub.ObjectValidators.LikeValidator
  alias Pleroma.Web.ActivityPub.ObjectValidators.Types
  alias Pleroma.Web.ActivityPub.ObjectValidators.UndoValidator

  @spec validate(map(), keyword()) :: {:ok, map(), keyword()} | {:error, any()}
  def validate(object, meta)

  def validate(%{"type" => "Undo"} = object, meta) do
    with {:ok, object} <-
           object
           |> UndoValidator.cast_and_validate()
           |> Ecto.Changeset.apply_action(:insert) do
      object = stringify_keys(object)
      {:ok, object, meta}
    end
  end

  def validate(%{"type" => "Delete"} = object, meta) do
    with cng <- DeleteValidator.cast_and_validate(object),
         do_not_federate <- DeleteValidator.do_not_federate?(cng),
         {:ok, object} <- Ecto.Changeset.apply_action(cng, :insert) do
      object = stringify_keys(object)
      meta = Keyword.put(meta, :do_not_federate, do_not_federate)
      {:ok, object, meta}
    end
  end

  def validate(%{"type" => "Like"} = object, meta) do
    with {:ok, object} <-
           object |> LikeValidator.cast_and_validate() |> Ecto.Changeset.apply_action(:insert) do
      object = stringify_keys(object |> Map.from_struct())
      {:ok, object, meta}
    end
  end

  def validate(%{"type" => "EmojiReact"} = object, meta) do
    with {:ok, object} <-
           object
           |> EmojiReactValidator.cast_and_validate()
           |> Ecto.Changeset.apply_action(:insert) do
      object = stringify_keys(object |> Map.from_struct())
      {:ok, object, meta}
    end
  end

  def validate(%{"type" => "Announce"} = object, meta) do
    with {:ok, object} <-
           object
           |> AnnounceValidator.cast_and_validate()
           |> Ecto.Changeset.apply_action(:insert) do
      object = stringify_keys(object |> Map.from_struct())
      {:ok, object, meta}
    end
  end

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
