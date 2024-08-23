# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Workers.ReceiverWorker do
  alias Pleroma.Signature
  alias Pleroma.User
  alias Pleroma.Web.Federator

  use Oban.Worker, queue: :federator_incoming, max_attempts: 5

  @impl true

  def perform(%Job{
        args: %{
          "op" => "incoming_ap_doc",
          "method" => method,
          "params" => params,
          "req_headers" => req_headers,
          "request_path" => request_path,
          "query_string" => query_string
        }
      }) do
    # Oban's serialization converts our tuple headers to lists.
    # Revert it for the signature validation.
    req_headers = Enum.into(req_headers, [], &List.to_tuple(&1))

    conn_data = %Plug.Conn{
      method: method,
      params: params,
      req_headers: req_headers,
      request_path: request_path,
      query_string: query_string
    }

    with {_, false} <- {:unknown_delete, unknown_delete?(params)},
         User.get_or_fetch_by_ap_id(conn_data.params["actor"]),
         {:ok, _public_key} <- Signature.refetch_public_key(conn_data),
         {:signature, true} <- {:signature, Signature.validate_signature(conn_data)},
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

  @impl true
  def timeout(%_{args: %{"timeout" => timeout}}), do: timeout

  def timeout(_job), do: :timer.seconds(5)

  defp process_errors(errors) do
    case errors do
      {:unknown_delete, true} -> {:cancel, "Delete from unknown actor"}
      {:error, :origin_containment_failed} -> {:cancel, :origin_containment_failed}
      {:error, :already_present} -> {:cancel, :already_present}
      {:error, {:validate_object, _} = reason} -> {:cancel, reason}
      {:error, {:error, {:validate, {:error, _changeset} = reason}}} -> {:cancel, reason}
      {:error, {:reject, _} = reason} -> {:cancel, reason}
      {:signature, false} -> {:cancel, :invalid_signature}
      {:error, "Object has been deleted"} = reason -> {:cancel, reason}
      {:error, {:side_effects, {:error, :no_object_actor}} = reason} -> {:cancel, reason}
      {:error, :not_found} = reason -> {:cancel, reason}
      {:error, _} = e -> e
      e -> {:error, e}
    end
  end

  defp unknown_delete?(%{
         "type" => "Delete",
         "actor" => actor
       }) do
    case User.get_cached_by_ap_id(actor) do
      %User{} -> false
      _ -> true
    end
  end

  defp unknown_delete?(_), do: false
end
