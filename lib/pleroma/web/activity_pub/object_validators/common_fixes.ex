# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.ObjectValidators.CommonFixes do
  alias Pleroma.EctoType.ActivityPub.ObjectValidators
  alias Pleroma.Object.Containment
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.Transmogrifier
  alias Pleroma.Web.ActivityPub.Utils

  def cast_recipients(message, field, field_fallback \\ []) do
    {:ok, data} = ObjectValidators.Recipients.cast(message[field] || field_fallback)

    Map.put(message, field, data)
  end

  def fix_object_defaults(data) do
    %{data: %{"id" => context}, id: context_id} =
      Utils.create_context(data["context"] || data["conversation"])

    %User{follower_address: follower_collection} = User.get_cached_by_ap_id(data["attributedTo"])

    data
    |> Map.put("context", context)
    |> Map.put("context_id", context_id)
    |> cast_recipients("to")
    |> cast_recipients("cc")
    |> cast_recipients("bto")
    |> cast_recipients("bcc")
    |> Transmogrifier.fix_explicit_addressing(follower_collection)
    |> Transmogrifier.fix_implicit_addressing(follower_collection)
  end

  def fix_activity_addressing(activity, _meta) do
    %User{follower_address: follower_collection} = User.get_cached_by_ap_id(activity["actor"])

    activity
    |> cast_recipients("to")
    |> cast_recipients("cc")
    |> cast_recipients("bto")
    |> cast_recipients("bcc")
    |> Transmogrifier.fix_explicit_addressing(follower_collection)
    |> Transmogrifier.fix_implicit_addressing(follower_collection)
  end

  def fix_actor(data) do
    actor =
      data
      |> Map.put_new("actor", data["attributedTo"])
      |> Containment.get_actor()

    data
    |> Map.put("actor", actor)
    |> Map.put("attributedTo", actor)
  end
end
