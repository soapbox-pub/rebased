# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.HTTP.RequestBuilder do
  @moduledoc """
  Helper functions for building Tesla requests
  """

  alias Pleroma.HTTP.Request
  alias Tesla.Multipart

  @doc """
  Creates new request
  """
  @spec new(Request.t()) :: Request.t()
  def new(%Request{} = request \\ %Request{}), do: request

  @doc """
  Specify the request method when building a request
  """
  @spec method(Request.t(), Request.method()) :: Request.t()
  def method(request, m), do: %{request | method: m}

  @doc """
  Specify the request method when building a request
  """
  @spec url(Request.t(), Request.url()) :: Request.t()
  def url(request, u), do: %{request | url: u}

  @doc """
  Add headers to the request
  """
  @spec headers(Request.t(), Request.headers()) :: Request.t()
  def headers(request, headers) do
    headers_list =
      if Pleroma.Config.get([:http, :send_user_agent]) do
        [{"user-agent", Pleroma.Application.user_agent()} | headers]
      else
        headers
      end

    %{request | headers: headers_list}
  end

  @doc """
  Add custom, per-request middleware or adapter options to the request
  """
  @spec opts(Request.t(), keyword()) :: Request.t()
  def opts(request, options), do: %{request | opts: options}

  @doc """
  Add optional parameters to the request
  """
  @spec add_param(Request.t(), atom(), atom(), any()) :: Request.t()
  def add_param(request, :query, :query, values), do: %{request | query: values}

  def add_param(request, :body, :body, value), do: %{request | body: value}

  def add_param(request, :body, key, value) do
    request
    |> Map.put(:body, Multipart.new())
    |> Map.update!(
      :body,
      &Multipart.add_field(
        &1,
        key,
        Jason.encode!(value),
        headers: [{"content-type", "application/json"}]
      )
    )
  end

  def add_param(request, :file, name, path) do
    request
    |> Map.put(:body, Multipart.new())
    |> Map.update!(:body, &Multipart.add_file(&1, path, name: name))
  end

  def add_param(request, :form, name, value) do
    Map.update(request, :body, %{name => value}, &Map.put(&1, name, value))
  end

  def add_param(request, location, key, value) do
    Map.update(request, location, [{key, value}], &(&1 ++ [{key, value}]))
  end

  def convert_to_keyword(request) do
    request
    |> Map.from_struct()
    |> Enum.into([])
  end
end
