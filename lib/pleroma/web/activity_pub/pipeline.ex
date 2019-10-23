# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.Pipeline do
  alias Pleroma.Activity
  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Pleroma.Web.ActivityPub.MRF
  alias Pleroma.Web.ActivityPub.ObjectValidator
  alias Pleroma.Web.ActivityPub.SideEffects
  alias Pleroma.Web.Federator

  @spec common_pipeline(map(), keyword()) :: {:ok, Activity.t(), keyword()} | {:error, any()}
  def common_pipeline(object, meta) do
    with {_, {:ok, validated_object, meta}} <-
           {:validate_object, ObjectValidator.validate(object, meta)},
         {_, {:ok, mrfd_object}} <- {:mrf_object, MRF.filter(validated_object)},
         {_, {:ok, %Activity{} = activity, meta}} <-
           {:persist_object, ActivityPub.persist(mrfd_object, meta)},
         {_, {:ok, %Activity{} = activity, meta}} <-
           {:execute_side_effects, SideEffects.handle(activity, meta)},
         {_, {:ok, _}} <- {:federation, maybe_federate(activity, meta)} do
      {:ok, activity, meta}
    else
      e -> {:error, e}
    end
  end

  defp maybe_federate(activity, meta) do
    with {:ok, local} <- Keyword.fetch(meta, :local) do
      if local do
        Federator.publish(activity)
        {:ok, :federated}
      else
        {:ok, :not_federated}
      end
    else
      _e -> {:error, "local not set in meta"}
    end
  end
end
