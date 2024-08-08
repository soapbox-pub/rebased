# Pleroma: A lightweight social networking server
# Copyright © 2017-2023 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.MRF.QuietReply do
  require Pleroma.Constants

  alias Pleroma.User

  @behaviour Pleroma.Web.ActivityPub.MRF.Policy

  @impl true
  def history_awareness, do: :auto

  @impl true
  def filter(
        %{
          "type" => "Create",
          "object" => %{
            "actor" => actor,
            "type" => "Note",
            "to" => to,
            "cc" => cc,
            "inReplyTo" => in_reply_to
          }
        } = object
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

      updated_object =
        object
        |> put_in(["object", "to"], updated_to)
        |> put_in(["object", "cc"], updated_cc)

      {:ok, updated_object}
    else
      _ -> {:ok, object}
    end
  end

  @impl true
  def filter(object), do: {:ok, object}

  @impl true
  def describe, do: {:ok, %{}}
end
