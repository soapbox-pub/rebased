# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.MRF.KeywordPolicy do
  @behaviour Pleroma.Web.ActivityPub.MRF
  defp string_matches?(string, pattern) when is_binary(pattern) do
    String.contains?(string, pattern)
  end

  defp string_matches?(string, pattern) do
    String.match?(string, pattern)
  end

  defp check_reject(%{"object" => %{"content" => content}} = message) do
    if Enum.any?(Pleroma.Config.get([:mrf_keyword, :reject]), fn pattern ->
         string_matches?(content, pattern)
       end) do
      {:reject, nil}
    else
      {:ok, message}
    end
  end

  defp check_ftl_removal(%{"to" => to, "object" => %{"content" => content}} = message) do
    if "https://www.w3.org/ns/activitystreams#Public" in to and
         Enum.any?(Pleroma.Config.get([:mrf_keyword, :federated_timeline_removal]), fn pattern ->
           string_matches?(content, pattern)
         end) do
      to = List.delete(to, "https://www.w3.org/ns/activitystreams#Public")
      cc = ["https://www.w3.org/ns/activitystreams#Public" | message["cc"] || []]

      message =
        message
        |> Map.put("to", to)
        |> Map.put("cc", cc)

      IO.inspect(message)
      {:ok, message}
    else
      {:ok, message}
    end
  end

  defp check_replace(%{"object" => %{"content" => content}} = message) do
    content =
      Enum.reduce(Pleroma.Config.get([:mrf_keyword, :replace]), content, fn {pattern, replacement},
                                                                            acc ->
        String.replace(acc, pattern, replacement)
      end)

    {:ok, put_in(message["object"]["content"], content)}
  end

  @impl true
  def filter(%{"object" => %{"content" => nil}} = message) do
    {:ok, message}
  end

  @impl true
  def filter(%{"type" => "Create", "object" => %{"content" => _content}} = message) do
    with {:ok, message} <- check_reject(message),
         {:ok, message} <- check_ftl_removal(message),
         {:ok, message} <- check_replace(message) do
      {:ok, message}
    else
      _e ->
        {:reject, nil}
    end
  end

  @impl true
  def filter(message), do: {:ok, message}
end
