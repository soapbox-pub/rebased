# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ControllerHelper do
  use Pleroma.Web, :controller

  # As in MastoAPI, per https://api.rubyonrails.org/classes/ActiveModel/Type/Boolean.html
  @falsy_param_values [false, 0, "0", "f", "F", "false", "FALSE", "off", "OFF"]
  def truthy_param?(blank_value) when blank_value in [nil, ""], do: nil
  def truthy_param?(value), do: value not in @falsy_param_values

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

  def add_link_headers(
        conn,
        method,
        activities,
        param \\ nil,
        params \\ %{},
        func3 \\ nil,
        func4 \\ nil
      ) do
    params =
      conn.params
      |> Map.drop(["since_id", "max_id", "min_id"])
      |> Map.merge(params)

    last = List.last(activities)

    func3 = func3 || (&mastodon_api_url/3)
    func4 = func4 || (&mastodon_api_url/4)

    if last do
      max_id = last.id

      limit =
        params
        |> Map.get("limit", "20")
        |> String.to_integer()

      min_id =
        if length(activities) <= limit do
          activities
          |> List.first()
          |> Map.get(:id)
        else
          activities
          |> Enum.at(limit * -1)
          |> Map.get(:id)
        end

      {next_url, prev_url} =
        if param do
          {
            func4.(
              Pleroma.Web.Endpoint,
              method,
              param,
              Map.merge(params, %{max_id: max_id})
            ),
            func4.(
              Pleroma.Web.Endpoint,
              method,
              param,
              Map.merge(params, %{min_id: min_id})
            )
          }
        else
          {
            func3.(
              Pleroma.Web.Endpoint,
              method,
              Map.merge(params, %{max_id: max_id})
            ),
            func3.(
              Pleroma.Web.Endpoint,
              method,
              Map.merge(params, %{min_id: min_id})
            )
          }
        end

      conn
      |> put_resp_header("link", "<#{next_url}>; rel=\"next\", <#{prev_url}>; rel=\"prev\"")
    else
      conn
    end
  end
end
