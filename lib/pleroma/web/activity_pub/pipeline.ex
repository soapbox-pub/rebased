# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.Pipeline do
  alias Pleroma.Activity
  alias Pleroma.Config
  alias Pleroma.Object
  alias Pleroma.Repo
  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Pleroma.Web.ActivityPub.MRF
  alias Pleroma.Web.ActivityPub.ObjectValidator
  alias Pleroma.Web.ActivityPub.SideEffects
  alias Pleroma.Web.ActivityPub.Visibility
  alias Pleroma.Web.Federator

  @side_effects Config.get([:pipeline, :side_effects], SideEffects)
  @federator Config.get([:pipeline, :federator], Federator)
  @object_validator Config.get([:pipeline, :object_validator], ObjectValidator)
  @mrf Config.get([:pipeline, :mrf], MRF)
  @activity_pub Config.get([:pipeline, :activity_pub], ActivityPub)
  @config Config.get([:pipeline, :config], Config)

  @spec common_pipeline(map(), keyword()) ::
          {:ok, Activity.t() | Object.t(), keyword()} | {:error, any()}
  def common_pipeline(object, meta) do
    case Repo.transaction(fn -> do_common_pipeline(object, meta) end) do
      {:ok, {:ok, activity, meta}} ->
        @side_effects.handle_after_transaction(meta)
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

  def do_common_pipeline(object, meta) do
    with {_, {:ok, validated_object, meta}} <-
           {:validate_object, @object_validator.validate(object, meta)},
         {_, {:ok, mrfd_object, meta}} <-
           {:mrf_object, @mrf.pipeline_filter(validated_object, meta)},
         {_, {:ok, activity, meta}} <-
           {:persist_object, @activity_pub.persist(mrfd_object, meta)},
         {_, {:ok, activity, meta}} <-
           {:execute_side_effects, @side_effects.handle(activity, meta)},
         {_, {:ok, _}} <- {:federation, maybe_federate(activity, meta)} do
      {:ok, activity, meta}
    else
      {:mrf_object, {:reject, message, _}} -> {:reject, message}
      e -> {:error, e}
    end
  end

  defp maybe_federate(%Object{}, _), do: {:ok, :not_federated}

  defp maybe_federate(%Activity{} = activity, meta) do
    with {:ok, local} <- Keyword.fetch(meta, :local) do
      do_not_federate = meta[:do_not_federate] || !@config.get([:instance, :federating])

      if !do_not_federate and local and not Visibility.is_local_public?(activity) do
        activity =
          if object = Keyword.get(meta, :object_data) do
            %{activity | data: Map.put(activity.data, "object", object)}
          else
            activity
          end

        @federator.publish(activity)
        {:ok, :federated}
      else
        {:ok, :not_federated}
      end
    else
      _e -> {:error, :badarg}
    end
  end
end
