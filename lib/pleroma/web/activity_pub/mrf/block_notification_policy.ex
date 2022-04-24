# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.MRF.BlockNotificationPolicy do
  @moduledoc "Notify local users upon remote block and unblock."
  @behaviour Pleroma.Web.ActivityPub.MRF.Policy

  alias Pleroma.Config
  alias Pleroma.User
  alias Pleroma.Web.CommonAPI

  defp is_block_or_unblock(%{"type" => "Block", "object" => object}),
    do: {true, "blocked", object}

  defp is_block_or_unblock(%{
         "type" => "Undo",
         "object" => %{"type" => "Block", "object" => object}
       }),
       do: {true, "unblocked", object}

  defp is_block_or_unblock(_), do: {false, nil, nil}

  @impl true
  def filter(message) do
    with {true, action, object} <- is_block_or_unblock(message),
         %User{} = actor <- User.get_cached_by_ap_id(message["actor"]),
         %User{} = recipient <- User.get_cached_by_ap_id(object) do
      bot_user = Pleroma.Config.get([:mrf_block_notification_policy, :user])

      replacements = %{
        "actor" => actor.nickname,
        "target" => recipient.nickname,
        "action" => action
      }

      msg =
        Regex.replace(
          ~r/{([a-z]+)?}/,
          Pleroma.Config.get([:mrf_block_notification_policy, :message]),
          fn _, match ->
            replacements[match]
          end
        )

      _reply =
        CommonAPI.post(User.get_by_nickname(bot_user), %{
          status: msg,
          visibility: Pleroma.Config.get([:mrf_block_notification_policy, :visibility])
        })
    end

    {:ok, message}
  end

  @impl true
  def describe do
    mrf_block_notification_policy = Config.get(:mrf_block_notification_policy)

    {:ok, %{mrf_block_notification_policy: mrf_block_notification_policy}}
  end

  @impl true
  def config_description do
    %{
      key: :mrf_block_notification_policy,
      related_policy: "Pleroma.Web.ActivityPub.MRF.BlockNotificationPolicy",
      description: "Notify local users upon remote block.",
      children: [
        %{
          key: :message,
          type: :string,
          label: "Message",
          description:
            "The message to send when someone is blocked or unblocked; use {actor}, {target}, and {action} variables",
          suggestions: ["@{actor} {action} @{target}"]
        },
        %{
          key: :user,
          type: :string,
          label: "Block User",
          description: "The user account that announces a block"
        },
        %{
          key: :visibility,
          type: :string,
          label: "Visibility",
          description: "The visibility of block messages",
          suggestions: ["public", "unlisted", "private", "direct"]
        }
      ]
    }
  end
end
