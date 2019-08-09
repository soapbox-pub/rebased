# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Federator.Publisher do
  alias Pleroma.Activity
  alias Pleroma.Config
  alias Pleroma.User
  alias Pleroma.Workers.Publisher, as: PublisherWorker

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
  @spec enqueue_one(module(), Map.t()) :: :ok
  def enqueue_one(module, %{} = params) do
    worker_args =
      if max_attempts = Pleroma.Config.get([:workers, :retries, :federator_outgoing]) do
        [max_attempts: max_attempts]
      else
        []
      end

    %{"op" => "publish_one", "module" => to_string(module), "params" => params}
    |> PublisherWorker.new(worker_args)
    |> Pleroma.Repo.insert()
  end

  @doc """
  Relays an activity to all specified peers.
  """
  @callback publish(User.t(), Activity.t()) :: :ok | {:error, any()}

  @spec publish(User.t(), Activity.t()) :: :ok
  def publish(%User{} = user, %Activity{} = activity) do
    Config.get([:instance, :federation_publisher_modules])
    |> Enum.each(fn module ->
      if module.is_representable?(activity) do
        Logger.info("Publishing #{activity.data["id"]} using #{inspect(module)}")
        module.publish(user, activity)
      end
    end)

    :ok
  end

  @doc """
  Gathers links used by an outgoing federation module for WebFinger output.
  """
  @callback gather_webfinger_links(User.t()) :: list()

  @spec gather_webfinger_links(User.t()) :: list()
  def gather_webfinger_links(%User{} = user) do
    Config.get([:instance, :federation_publisher_modules])
    |> Enum.reduce([], fn module, links ->
      links ++ module.gather_webfinger_links(user)
    end)
  end

  @doc """
  Gathers nodeinfo protocol names supported by the federation module.
  """
  @callback gather_nodeinfo_protocol_names() :: list()

  @spec gather_nodeinfo_protocol_names() :: list()
  def gather_nodeinfo_protocol_names do
    Config.get([:instance, :federation_publisher_modules])
    |> Enum.reduce([], fn module, links ->
      links ++ module.gather_nodeinfo_protocol_names()
    end)
  end
end
