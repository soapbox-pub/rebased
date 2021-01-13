# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.User.Import do
  use Ecto.Schema

  alias Pleroma.User
  alias Pleroma.Web.CommonAPI
  alias Pleroma.Workers.BackgroundWorker

  require Logger

  @spec perform(atom(), User.t(), list()) :: :ok | list() | {:error, any()}
  def perform(:mutes_import, %User{} = user, [_ | _] = identifiers) do
    Enum.map(
      identifiers,
      fn identifier ->
        with {:ok, %User{} = muted_user} <- User.get_or_fetch(identifier),
             {:ok, _} <- User.mute(user, muted_user) do
          muted_user
        else
          error -> handle_error(:mutes_import, identifier, error)
        end
      end
    )
  end

  def perform(:blocks_import, %User{} = blocker, [_ | _] = identifiers) do
    Enum.map(
      identifiers,
      fn identifier ->
        with {:ok, %User{} = blocked} <- User.get_or_fetch(identifier),
             {:ok, _block} <- CommonAPI.block(blocker, blocked) do
          blocked
        else
          error -> handle_error(:blocks_import, identifier, error)
        end
      end
    )
  end

  def perform(:follow_import, %User{} = follower, [_ | _] = identifiers) do
    Enum.map(
      identifiers,
      fn identifier ->
        with {:ok, %User{} = followed} <- User.get_or_fetch(identifier),
             {:ok, follower, followed} <- User.maybe_direct_follow(follower, followed),
             {:ok, _, _, _} <- CommonAPI.follow(follower, followed) do
          followed
        else
          error -> handle_error(:follow_import, identifier, error)
        end
      end
    )
  end

  def perform(_, _, _), do: :ok

  defp handle_error(op, user_id, error) do
    Logger.debug("#{op} failed for #{user_id} with: #{inspect(error)}")
    error
  end

  def blocks_import(%User{} = blocker, [_ | _] = identifiers) do
    BackgroundWorker.enqueue(
      "blocks_import",
      %{"user_id" => blocker.id, "identifiers" => identifiers}
    )
  end

  def follow_import(%User{} = follower, [_ | _] = identifiers) do
    BackgroundWorker.enqueue(
      "follow_import",
      %{"user_id" => follower.id, "identifiers" => identifiers}
    )
  end

  def mutes_import(%User{} = user, [_ | _] = identifiers) do
    BackgroundWorker.enqueue(
      "mutes_import",
      %{"user_id" => user.id, "identifiers" => identifiers}
    )
  end
end
