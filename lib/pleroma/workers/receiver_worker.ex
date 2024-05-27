# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Workers.ReceiverWorker do
  alias Pleroma.Signature
  alias Pleroma.User
  alias Pleroma.Web.Federator

  use Pleroma.Workers.WorkerHelper, queue: "federator_incoming"

  @impl Oban.Worker

  def perform(%Job{
        args: %{"op" => "incoming_ap_doc", "req_headers" => req_headers, "params" => params}
      }) do
    # Oban's serialization converts our tuple headers to lists.
    # Revert it for the signature validation.
    req_headers = Enum.into(req_headers, [], &List.to_tuple(&1))

    conn_data = %{params: params, req_headers: req_headers}

    with {:ok, %User{} = _actor} <- User.get_or_fetch_by_ap_id(conn_data.params["actor"]),
         {:ok, _public_key} <- Signature.refetch_public_key(conn_data),
         {:signature, true} <- {:signature, HTTPSignatures.validate_conn(conn_data)},
         {:ok, res} <- Federator.perform(:incoming_ap_doc, params) do
      {:ok, res}
    else
      e -> process_errors(e)
    end
  end

  def perform(%Job{args: %{"op" => "incoming_ap_doc", "params" => params}}) do
    with {:ok, res} <- Federator.perform(:incoming_ap_doc, params) do
      {:ok, res}
    else
      e -> process_errors(e)
    end
  end

  @impl Oban.Worker
  def timeout(%_{args: %{"timeout" => timeout}}), do: timeout

  def timeout(_job), do: :timer.seconds(5)

  defp process_errors(errors) do
    case errors do
      {:error, :origin_containment_failed} -> {:cancel, :origin_containment_failed}
      {:error, :already_present} -> {:cancel, :already_present}
      {:error, {:validate_object, reason}} -> {:cancel, reason}
      {:error, {:error, {:validate, reason}}} -> {:cancel, reason}
      {:error, {:reject, reason}} -> {:cancel, reason}
      {:signature, false} -> {:cancel, :invalid_signature}
      {:error, {:error, reason = "Object has been deleted"}} -> {:cancel, reason}
      {:error, _} = e -> e
      e -> {:error, e}
    end
  end
end
