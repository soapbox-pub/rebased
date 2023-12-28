# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Federator.Publisher do
  alias Pleroma.User
  alias Pleroma.Workers.PublisherWorker

  require Logger

  @moduledoc """
  Defines the contract used by federation implementations to publish messages to
  their peers.
  """

  @doc """
  Determine whether an activity can be relayed using the federation module.
  """
  @callback is_representable?(Pleroma.Activity.t()) :: boolean()

  @doc """
  Relays an activity to a specified peer, determined by the parameters.  The
  parameters used are controlled by the federation module.
  """
  @callback publish_one(Map.t()) :: {:ok, Map.t()} | {:error, any()}

  @doc """
  Enqueue publishing a single activity.
  """
  @spec enqueue_one(module(), Map.t(), Keyword.t()) :: {:ok, %Oban.Job{}}
  def enqueue_one(module, %{} = params, worker_args \\ []) do
    PublisherWorker.enqueue(
      "publish_one",
      %{"module" => to_string(module), "params" => params},
      worker_args
    )
  end

  @doc """
  Gathers a set of remote users given an IR envelope.
  """
  def remote_users(%User{id: user_id}, %{data: %{"to" => to} = data}) do
    cc = Map.get(data, "cc", [])

    bcc =
      data
      |> Map.get("bcc", [])
      |> Enum.reduce([], fn ap_id, bcc ->
        case Pleroma.List.get_by_ap_id(ap_id) do
          %Pleroma.List{user_id: ^user_id} = list ->
            {:ok, following} = Pleroma.List.get_following(list)
            bcc ++ Enum.map(following, & &1.ap_id)

          _ ->
            bcc
        end
      end)

    [to, cc, bcc]
    |> Enum.concat()
    |> Enum.map(&User.get_cached_by_ap_id/1)
    |> Enum.filter(fn user -> user && !user.local end)
  end
end
