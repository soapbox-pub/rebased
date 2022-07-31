# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.MRF.HashtagPolicy do
  require Pleroma.Constants

  alias Pleroma.Config
  alias Pleroma.Object

  @moduledoc """
  Reject, TWKN-remove or Set-Sensitive messsages with specific hashtags (without the leading #)

  Note: This MRF Policy is always enabled, if you want to disable it you have to set empty lists.
  """

  @behaviour Pleroma.Web.ActivityPub.MRF.Policy

  defp check_reject(message, hashtags) do
    if Enum.any?(Config.get([:mrf_hashtag, :reject]), fn match -> match in hashtags end) do
      {:reject, "[HashtagPolicy] Matches with rejected keyword"}
    else
      {:ok, message}
    end
  end

  defp check_ftl_removal(%{"to" => to} = message, hashtags) do
    if Pleroma.Constants.as_public() in to and
         Enum.any?(Config.get([:mrf_hashtag, :federated_timeline_removal]), fn match ->
           match in hashtags
         end) do
      to = List.delete(to, Pleroma.Constants.as_public())
      cc = [Pleroma.Constants.as_public() | message["cc"] || []]

      message =
        message
        |> Map.put("to", to)
        |> Map.put("cc", cc)
        |> Kernel.put_in(["object", "to"], to)
        |> Kernel.put_in(["object", "cc"], cc)

      {:ok, message}
    else
      {:ok, message}
    end
  end

  defp check_ftl_removal(message, _hashtags), do: {:ok, message}

  defp check_sensitive(message, hashtags) do
    if Enum.any?(Config.get([:mrf_hashtag, :sensitive]), fn match -> match in hashtags end) do
      {:ok, Kernel.put_in(message, ["object", "sensitive"], true)}
    else
      {:ok, message}
    end
  end

  @impl true
  def filter(%{"type" => "Create", "object" => object} = message) do
    hashtags = Object.hashtags(%Object{data: object})

    if hashtags != [] do
      with {:ok, message} <- check_reject(message, hashtags),
           {:ok, message} <- check_ftl_removal(message, hashtags),
           {:ok, message} <- check_sensitive(message, hashtags) do
        {:ok, message}
      end
    else
      {:ok, message}
    end
  end

  @impl true
  def filter(message), do: {:ok, message}

  @impl true
  def describe do
    mrf_hashtag =
      Config.get(:mrf_hashtag)
      |> Enum.into(%{})

    {:ok, %{mrf_hashtag: mrf_hashtag}}
  end

  @impl true
  def config_description do
    %{
      key: :mrf_hashtag,
      related_policy: "Pleroma.Web.ActivityPub.MRF.HashtagPolicy",
      label: "MRF Hashtag",
      description: @moduledoc,
      children: [
        %{
          key: :reject,
          type: {:list, :string},
          description: "A list of hashtags which result in message being rejected.",
          suggestions: ["foo"]
        },
        %{
          key: :federated_timeline_removal,
          type: {:list, :string},
          description:
            "A list of hashtags which result in message being removed from federated timelines (a.k.a unlisted).",
          suggestions: ["foo"]
        },
        %{
          key: :sensitive,
          type: {:list, :string},
          description:
            "A list of hashtags which result in message being set as sensitive (a.k.a NSFW/R-18)",
          suggestions: ["nsfw", "r18"]
        }
      ]
    }
  end
end
