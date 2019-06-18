# Pleroma: A lightweight social networking server
# Copyright _ 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.RichMedia.Helpers do
  alias Pleroma.Activity
  alias Pleroma.HTML
  alias Pleroma.Object
  alias Pleroma.Web.RichMedia.Parser

  defp validate_page_url(page_url) when is_binary(page_url) do
    validate_tld = Application.get_env(:auto_linker, :opts)[:validate_tld]

    if AutoLinker.Parser.url?(page_url, scheme: true, validate_tld: validate_tld) do
      URI.parse(page_url) |> validate_page_url
    else
      :error
    end
  end

  defp validate_page_url(%URI{authority: nil}), do: :error
  defp validate_page_url(%URI{scheme: nil}), do: :error
  defp validate_page_url(%URI{}), do: :ok
  defp validate_page_url(_), do: :error

  def fetch_data_for_activity(%Activity{data: %{"type" => "Create"}} = activity) do
    with true <- Pleroma.Config.get([:rich_media, :enabled]),
         %Object{} = object <- Object.normalize(activity),
         false <- object.data["sensitive"] || false,
         {:ok, page_url} <- HTML.extract_first_external_url(object, object.data["content"]),
         :ok <- validate_page_url(page_url),
         {:ok, rich_media} <- Parser.parse(page_url) do
      %{page_url: page_url, rich_media: rich_media}
    else
      _ -> %{}
    end
  end

  def fetch_data_for_activity(_), do: %{}

  def perform(:fetch, %Activity{} = activity), do: fetch_data_for_activity(activity)
end
