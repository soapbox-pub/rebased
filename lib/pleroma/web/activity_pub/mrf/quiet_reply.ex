# Pleroma: A lightweight social networking server
# Copyright © 2017-2023 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.MRF.QuietReply do
  @moduledoc """
  QuietReply alters the scope of activities from local users when replying by enforcing them to be "Unlisted" or "Quiet Public". This delivers the activity to all the expected recipients and instances, but it will not be published in the Federated / The Whole Known Network timelines. It will still be published to the Home timelines of the user's followers and visible to anyone who opens the thread.
  """
  require Pleroma.Constants

  alias Pleroma.User

  @behaviour Pleroma.Web.ActivityPub.MRF.Policy

  @impl true
  def history_awareness, do: :auto

  @impl true
  def filter(
        %{
          "type" => "Create",
          "to" => to,
          "cc" => cc,
          "object" => %{
            "actor" => actor,
            "type" => "Note",
            "inReplyTo" => in_reply_to
          }
        } = activity
      ) do
    with true <- is_binary(in_reply_to),
         false <- match?([], cc),
         %User{follower_address: followers_collection, local: true} <-
           User.get_by_ap_id(actor) do
      updated_to =
        to
        |> Kernel.++([followers_collection])
        |> Kernel.--([Pleroma.Constants.as_public()])

      updated_cc = [Pleroma.Constants.as_public()]

      updated_activity =
        activity
        |> Map.put("to", updated_to)
        |> Map.put("cc", updated_cc)
        |> put_in(["object", "to"], updated_to)
        |> put_in(["object", "cc"], updated_cc)

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
