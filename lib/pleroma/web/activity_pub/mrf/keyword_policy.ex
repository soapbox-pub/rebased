# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.MRF.KeywordPolicy do
  require Pleroma.Constants

  @moduledoc "Reject or Word-Replace messages with a keyword or regex"

  @behaviour Pleroma.Web.ActivityPub.MRF
  defp string_matches?(string, _) when not is_binary(string) do
    false
  end

  defp string_matches?(string, pattern) when is_binary(pattern) do
    String.contains?(string, pattern)
  end

  defp string_matches?(string, pattern) do
    String.match?(string, pattern)
  end

  defp object_payload(%{} = object) do
    [object["content"], object["summary"], object["name"]]
    |> Enum.filter(& &1)
    |> Enum.join("\n")
  end

  defp check_reject(%{"object" => %{} = object} = message) do
    payload = object_payload(object)

    if Enum.any?(Pleroma.Config.get([:mrf_keyword, :reject]), fn pattern ->
         string_matches?(payload, pattern)
       end) do
      {:reject, "[KeywordPolicy] Matches with rejected keyword"}
    else
      {:ok, message}
    end
  end

  defp check_ftl_removal(%{"to" => to, "object" => %{} = object} = message) do
    payload = object_payload(object)

    if Pleroma.Constants.as_public() in to and
         Enum.any?(Pleroma.Config.get([:mrf_keyword, :federated_timeline_removal]), fn pattern ->
           string_matches?(payload, pattern)
         end) do
      to = List.delete(to, Pleroma.Constants.as_public())
      cc = [Pleroma.Constants.as_public() | message["cc"] || []]

      message =
        message
        |> Map.put("to", to)
        |> Map.put("cc", cc)

      {:ok, message}
    else
      {:ok, message}
    end
  end

  defp check_replace(%{"object" => %{} = object} = message) do
    object =
      ["content", "name", "summary"]
      |> Enum.filter(fn field -> Map.has_key?(object, field) && object[field] end)
      |> Enum.reduce(object, fn field, object ->
        data =
          Enum.reduce(
            Pleroma.Config.get([:mrf_keyword, :replace]),
            object[field],
            fn {pat, repl}, acc -> String.replace(acc, pat, repl) end
          )

        Map.put(object, field, data)
      end)

    message = Map.put(message, "object", object)

    {:ok, message}
  end

  @impl true
  def filter(%{"type" => "Create", "object" => %{"content" => _content}} = message) do
    with {:ok, message} <- check_reject(message),
         {:ok, message} <- check_ftl_removal(message),
         {:ok, message} <- check_replace(message) do
      {:ok, message}
    else
      {:reject, nil} -> {:reject, "[KeywordPolicy] "}
      {:reject, _} = e -> e
      _e -> {:reject, "[KeywordPolicy] "}
    end
  end

  @impl true
  def filter(message), do: {:ok, message}

  @impl true
  def describe do
    # This horror is needed to convert regex sigils to strings
    mrf_keyword =
      Pleroma.Config.get(:mrf_keyword, [])
      |> Enum.map(fn {key, value} ->
        {key,
         Enum.map(value, fn
           {pattern, replacement} ->
             %{
               "pattern" =>
                 if not is_binary(pattern) do
                   inspect(pattern)
                 else
                   pattern
                 end,
               "replacement" => replacement
             }

           pattern ->
             if not is_binary(pattern) do
               inspect(pattern)
             else
               pattern
             end
         end)}
      end)
      |> Enum.into(%{})

    {:ok, %{mrf_keyword: mrf_keyword}}
  end
end
