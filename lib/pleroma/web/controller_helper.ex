# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ControllerHelper do
  use Pleroma.Web, :controller

  alias Pleroma.Pagination
  alias Pleroma.Web.Utils.Params

  def json_response(conn, status, _) when status in [204, :no_content] do
    conn
    |> put_resp_header("content-type", "application/json")
    |> send_resp(status, "")
  end

  def json_response(conn, status, json) do
    conn
    |> put_status(status)
    |> json(json)
  end

  @spec fetch_integer_param(map(), String.t(), integer() | nil) :: integer() | nil
  def fetch_integer_param(params, name, default \\ nil) do
    params
    |> Map.get(name, default)
    |> param_to_integer(default)
  end

  defp param_to_integer(val, _) when is_integer(val), do: val

  defp param_to_integer(val, default) when is_binary(val) do
    case Integer.parse(val) do
      {res, _} -> res
      _ -> default
    end
  end

  defp param_to_integer(_, default), do: default

  def add_link_headers(conn, entries, extra_params \\ %{})

  def add_link_headers(%{assigns: %{skip_link_headers: true}} = conn, _entries, _extra_params),
    do: conn

  def add_link_headers(conn, entries, extra_params) do
    case get_pagination_fields(conn, entries, extra_params) do
      %{"next" => next_url, "prev" => prev_url} ->
        put_resp_header(conn, "link", "<#{next_url}>; rel=\"next\", <#{prev_url}>; rel=\"prev\"")

      _ ->
        conn
    end
  end

  @id_keys Pagination.page_keys() -- ["limit", "order"]
  defp build_pagination_fields(conn, min_id, max_id, extra_params) do
    params =
      conn.params
      |> Map.drop(Map.keys(conn.path_params) |> Enum.map(&String.to_existing_atom/1))
      |> Map.merge(extra_params)
      |> Map.drop(@id_keys)

    %{
      "next" => current_url(conn, Map.put(params, :max_id, max_id)),
      "prev" => current_url(conn, Map.put(params, :min_id, min_id)),
      "id" => current_url(conn)
    }
  end

  def get_pagination_fields(conn, entries, extra_params \\ %{}) do
    case List.last(entries) do
      %{pagination_id: max_id} when not is_nil(max_id) ->
        %{pagination_id: min_id} = List.first(entries)

        build_pagination_fields(conn, min_id, max_id, extra_params)

      %{id: max_id} ->
        %{id: min_id} = List.first(entries)

        build_pagination_fields(conn, min_id, max_id, extra_params)

      _ ->
        %{}
    end
  end

  def assign_account_by_id(conn, _) do
    case Pleroma.User.get_cached_by_id(conn.params.id) do
      %Pleroma.User{} = account -> assign(conn, :account, account)
      nil -> Pleroma.Web.MastodonAPI.FallbackController.call(conn, {:error, :not_found}) |> halt()
    end
  end

  def try_render(conn, target, params) when is_binary(target) do
    case render(conn, target, params) do
      nil -> render_error(conn, :not_implemented, "Can't display this activity")
      res -> res
    end
  end

  def try_render(conn, _, _) do
    render_error(conn, :not_implemented, "Can't display this activity")
  end

  @doc """
  Returns true if request specifies to include embedded relationships in account objects.
  May only be used in selected account-related endpoints; has no effect for status- or
    notification-related endpoints.
  """
  # Intended for PleromaFE: https://git.pleroma.social/pleroma/pleroma-fe/-/issues/838
  def embed_relationships?(params) do
    # To do once OpenAPI transition mess is over: just `truthy_param?(params[:with_relationships])`
    params
    |> Map.get(:with_relationships, params["with_relationships"])
    |> Params.truthy_param?()
  end
end
