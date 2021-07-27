# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.Pipeline do
  alias Pleroma.Activity
  alias Pleroma.Config
  alias Pleroma.Object
  alias Pleroma.Repo
  alias Pleroma.Utils
  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Pleroma.Web.ActivityPub.MRF
  alias Pleroma.Web.ActivityPub.ObjectValidator
  alias Pleroma.Web.ActivityPub.SideEffects
  alias Pleroma.Web.ActivityPub.Visibility
  alias Pleroma.Web.Federator

  defp side_effects, do: Config.get([:pipeline, :side_effects], SideEffects)
  defp federator, do: Config.get([:pipeline, :federator], Federator)
  defp object_validator, do: Config.get([:pipeline, :object_validator], ObjectValidator)
  defp mrf, do: Config.get([:pipeline, :mrf], MRF)
  defp activity_pub, do: Config.get([:pipeline, :activity_pub], ActivityPub)
  defp config, do: Config.get([:pipeline, :config], Config)

  @spec common_pipeline(map(), keyword()) ::
          {:ok, Activity.t() | Object.t(), keyword()} | {:error, any()}
  def common_pipeline(object, meta) do
    case Repo.transaction(fn -> do_common_pipeline(object, meta) end, Utils.query_timeout()) do
      {:ok, {:ok, activity, meta}} ->
        side_effects().handle_after_transaction(meta)
        {:ok, activity, meta}

      {:ok, value} ->
        value

      {:error, e} ->
        {:error, e}

      {:reject, e} ->
        {:reject, e}
    end
  end

  def do_common_pipeline(%{__struct__: _}, _meta), do: {:error, :is_struct}

  def do_common_pipeline(message, meta) do
    with {_, {:ok, message, meta}} <- {:validate, object_validator().validate(message, meta)},
         {_, {:ok, message, meta}} <- {:mrf, mrf().pipeline_filter(message, meta)},
         {_, {:ok, message, meta}} <- {:persist, activity_pub().persist(message, meta)},
         {_, {:ok, message, meta}} <- {:side_effects, side_effects().handle(message, meta)},
         {_, {:ok, _}} <- {:federation, maybe_federate(message, meta)} do
      {:ok, message, meta}
    else
      {:mrf, {:reject, message, _}} -> {:reject, message}
      e -> {:error, e}
    end
  end

  defp maybe_federate(%Object{}, _), do: {:ok, :not_federated}

  defp maybe_federate(%Activity{} = activity, meta) do
    with {:ok, local} <- Keyword.fetch(meta, :local) do
      do_not_federate = meta[:do_not_federate] || !config().get([:instance, :federating])

      if !do_not_federate and local and not Visibility.is_local_public?(activity) do
        activity =
          if object = Keyword.get(meta, :object_data) do
            %{activity | data: Map.put(activity.data, "object", object)}
          else
            activity
          end

        federator().publish(activity)
        {:ok, :federated}
      else
        {:ok, :not_federated}
      end
    else
      _e -> {:error, :badarg}
    end
  end
end
