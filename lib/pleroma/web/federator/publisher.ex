# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Federator.Publisher do
  alias Pleroma.Activity
  alias Pleroma.Config
  alias Pleroma.User
  alias Pleroma.Web.Federator.RetryQueue

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
  def enqueue_one(module, %{} = params),
    do: PleromaJobQueue.enqueue(:federation_outgoing, __MODULE__, [:publish_one, module, params])

  @spec perform(atom(), module(), any()) :: {:ok, any()} | {:error, any()}
  def perform(:publish_one, module, params) do
    case apply(module, :publish_one, [params]) do
      {:ok, _} ->
        :ok

      {:error, _e} ->
        RetryQueue.enqueue(params, module)
    end
  end

  def perform(type, _, _) do
    Logger.debug("Unknown task: #{type}")
    {:error, "Don't know what to do with this"}
  end

  @doc """
  Relays an activity to all specified peers.
  """
  @callback publish(Pleroma.User.t(), Pleroma.Activity.t()) :: :ok | {:error, any()}

  @spec publish(Pleroma.User.t(), Pleroma.Activity.t()) :: :ok
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
  @callback gather_webfinger_links(Pleroma.User.t()) :: list()

  @spec gather_webfinger_links(Pleroma.User.t()) :: list()
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
