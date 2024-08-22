# Pleroma: A lightweight social networking server
# Copyright © 2017-2024 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.MRF.FODirectReply do
  @moduledoc """
  FODirectReply alters the scope of replies to activities which are Followers Only to be Direct. The purpose of this policy is to prevent broken threads for followers of the reply author because their response was to a user that they are not also following.
  """

  alias Pleroma.Object
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.Visibility

  @behaviour Pleroma.Web.ActivityPub.MRF.Policy

  @impl true
  def filter(
        %{
          "type" => "Create",
          "to" => to,
          "object" => %{
            "actor" => actor,
            "type" => "Note",
            "inReplyTo" => in_reply_to
          }
        } = activity
      ) do
    with true <- is_binary(in_reply_to),
         %User{follower_address: followers_collection, local: true} <- User.get_by_ap_id(actor),
         %Object{} = in_reply_to_object <- Object.get_by_ap_id(in_reply_to),
         "private" <- Visibility.get_visibility(in_reply_to_object) do
      direct_to = to -- [followers_collection]

      updated_activity =
        activity
        |> Map.put("cc", [])
        |> Map.put("to", direct_to)
        |> Map.put("directMessage", true)
        |> put_in(["object", "cc"], [])
        |> put_in(["object", "to"], direct_to)

      {:ok, updated_activity}
    else
      _ -> {:ok, activity}
    end
  end

  @impl true
  def filter(activity), do: {:ok, activity}

  @impl true
  def describe, do: {:ok, %{}}
end
