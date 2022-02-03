# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.MRF.ForceBotUnlistedPolicy do
  alias Pleroma.User
  @behaviour Pleroma.Web.ActivityPub.MRF.Policy
  @moduledoc "Remove bot posts from federated timeline"

  require Pleroma.Constants

  defp check_by_actor_type(user), do: user.actor_type in ["Application", "Service"]
  defp check_by_nickname(user), do: Regex.match?(~r/.bot@|ebooks@/i, user.nickname)

  defp check_if_bot(user), do: check_by_actor_type(user) or check_by_nickname(user)

  @impl true
  def filter(
        %{
          "type" => "Create",
          "to" => to,
          "cc" => cc,
          "actor" => actor,
          "object" => object
        } = message
      ) do
    user = User.get_cached_by_ap_id(actor)
    isbot = check_if_bot(user)

    if isbot and Enum.member?(to, Pleroma.Constants.as_public()) do
      to = List.delete(to, Pleroma.Constants.as_public()) ++ [user.follower_address]
      cc = List.delete(cc, user.follower_address) ++ [Pleroma.Constants.as_public()]

      object =
        object
        |> Map.put("to", to)
        |> Map.put("cc", cc)

      message =
        message
        |> Map.put("to", to)
        |> Map.put("cc", cc)
        |> Map.put("object", object)

      {:ok, message}
    else
      {:ok, message}
    end
  end

  @impl true
  def filter(message), do: {:ok, message}

  @impl true
  def describe, do: {:ok, %{}}
end
