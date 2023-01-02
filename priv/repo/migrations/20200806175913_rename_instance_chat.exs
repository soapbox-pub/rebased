# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.RenameInstanceChat do
  use Ecto.Migration

  alias Pleroma.ConfigDB

  @instance_params %{group: :pleroma, key: :instance}
  @shout_params %{group: :pleroma, key: :shout}
  @chat_params %{group: :pleroma, key: :chat}

  def up do
    instance_updated? = maybe_update_instance_key(:up) != :noop
    chat_updated? = maybe_update_chat_key(:up) != :noop

    case Enum.any?([instance_updated?, chat_updated?]) do
      true -> :ok
      false -> :noop
    end
  end

  def down do
    instance_updated? = maybe_update_instance_key(:down) != :noop
    chat_updated? = maybe_update_chat_key(:down) != :noop

    case Enum.any?([instance_updated?, chat_updated?]) do
      true -> :ok
      false -> :noop
    end
  end

  # pleroma.instance.chat_limit -> pleroma.shout.limit
  defp maybe_update_instance_key(:up) do
    with %ConfigDB{value: values} <- ConfigDB.get_by_params(@instance_params),
         limit when is_integer(limit) <- values[:chat_limit] do
      @shout_params |> Map.put(:value, limit: limit) |> ConfigDB.update_or_create()
      @instance_params |> Map.put(:subkeys, [":chat_limit"]) |> ConfigDB.delete()
    else
      _ ->
        :noop
    end
  end

  # pleroma.shout.limit -> pleroma.instance.chat_limit
  defp maybe_update_instance_key(:down) do
    with %ConfigDB{value: values} <- ConfigDB.get_by_params(@shout_params),
         limit when is_integer(limit) <- values[:limit] do
      @instance_params |> Map.put(:value, chat_limit: limit) |> ConfigDB.update_or_create()
      @shout_params |> Map.put(:subkeys, [":limit"]) |> ConfigDB.delete()
    else
      _ ->
        :noop
    end
  end

  # pleroma.chat.enabled -> pleroma.shout.enabled
  defp maybe_update_chat_key(:up) do
    with %ConfigDB{value: values} <- ConfigDB.get_by_params(@chat_params),
         enabled? when is_boolean(enabled?) <- values[:enabled] do
      @shout_params |> Map.put(:value, enabled: enabled?) |> ConfigDB.update_or_create()
      @chat_params |> Map.put(:subkeys, [":enabled"]) |> ConfigDB.delete()
    else
      _ ->
        :noop
    end
  end

  # pleroma.shout.enabled -> pleroma.chat.enabled
  defp maybe_update_chat_key(:down) do
    with %ConfigDB{value: values} <- ConfigDB.get_by_params(@shout_params),
         enabled? when is_boolean(enabled?) <- values[:enabled] do
      @chat_params |> Map.put(:value, enabled: enabled?) |> ConfigDB.update_or_create()
      @shout_params |> Map.put(:subkeys, [":enabled"]) |> ConfigDB.delete()
    else
      _ ->
        :noop
    end
  end
end
