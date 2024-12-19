# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.User.Import do
  use Ecto.Schema

  alias Pleroma.Repo
  alias Pleroma.User
  alias Pleroma.Web.CommonAPI
  alias Pleroma.Workers.BackgroundWorker

  require Logger

  @spec perform(atom(), User.t(), String.t()) :: :ok | {:error, any()}
  def perform(:mute_import, %User{} = user, actor) do
    with {:ok, %User{} = muted_user} <- User.get_or_fetch(actor),
         {_, false} <- {:existing_mute, User.mutes_user?(user, muted_user)},
         {:ok, _} <- User.mute(user, muted_user) do
      {:ok, muted_user}
    else
      {:existing_mute, true} -> :ok
      error -> handle_error(:mutes_import, actor, error)
    end
  end

  def perform(:block_import, %User{} = user, actor) do
    with {:ok, %User{} = blocked} <- User.get_or_fetch(actor),
         {_, false} <- {:existing_block, User.blocks_user?(user, blocked)},
         {:ok, _block} <- CommonAPI.block(blocked, user) do
      {:ok, blocked}
    else
      {:existing_block, true} -> :ok
      error -> handle_error(:blocks_import, actor, error)
    end
  end

  def perform(:follow_import, %User{} = user, actor) do
    with {:ok, %User{} = followed} <- User.get_or_fetch(actor),
         {_, false} <- {:existing_follow, User.following?(user, followed)},
         {:ok, user, followed} <- User.maybe_direct_follow(user, followed),
         {:ok, _, _, _} <- CommonAPI.follow(followed, user) do
      {:ok, followed}
    else
      {:existing_follow, true} -> :ok
      error -> handle_error(:follow_import, actor, error)
    end
  end

  defp handle_error(op, user_id, error) do
    Logger.debug("#{op} failed for #{user_id} with: #{inspect(error)}")
    {:error, error}
  end

  def blocks_import(%User{} = user, [_ | _] = actors) do
    jobs =
      Repo.checkout(fn ->
        Enum.reduce(actors, [], fn actor, acc ->
          {:ok, job} =
            BackgroundWorker.new(%{
              "op" => "block_import",
              "user_id" => user.id,
              "actor" => actor
            })
            |> Oban.insert()

          acc ++ [job]
        end)
      end)

    {:ok, jobs}
  end

  def follows_import(%User{} = user, [_ | _] = actors) do
    jobs =
      Repo.checkout(fn ->
        Enum.reduce(actors, [], fn actor, acc ->
          {:ok, job} =
            BackgroundWorker.new(%{
              "op" => "follow_import",
              "user_id" => user.id,
              "actor" => actor
            })
            |> Oban.insert()

          acc ++ [job]
        end)
      end)

    {:ok, jobs}
  end

  def mutes_import(%User{} = user, [_ | _] = actors) do
    jobs =
      Repo.checkout(fn ->
        Enum.reduce(actors, [], fn actor, acc ->
          {:ok, job} =
            BackgroundWorker.new(%{
              "op" => "mute_import",
              "user_id" => user.id,
              "actor" => actor
            })
            |> Oban.insert()

          acc ++ [job]
        end)
      end)

    {:ok, jobs}
  end
end
