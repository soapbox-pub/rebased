# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.MRF.HashtagPolicy do
  require Pleroma.Constants

  alias Pleroma.Config
  alias Pleroma.Object

  @moduledoc """
  Reject, TWKN-remove or Set-Sensitive activities with specific hashtags (without the leading #)

  Note: This MRF Policy is always enabled, if you want to disable it you have to set empty lists.
  """

  @behaviour Pleroma.Web.ActivityPub.MRF.Policy

  @impl true
  def history_awareness, do: :manual

  defp check_reject(activity, hashtags) do
    if Enum.any?(Config.get([:mrf_hashtag, :reject]), fn match -> match in hashtags end) do
      {:reject, "[HashtagPolicy] Matches with rejected keyword"}
    else
      {:ok, activity}
    end
  end

  defp check_ftl_removal(%{"to" => to} = activity, hashtags) do
    if Pleroma.Constants.as_public() in to and
         Enum.any?(Config.get([:mrf_hashtag, :federated_timeline_removal]), fn match ->
           match in hashtags
         end) do
      to = List.delete(to, Pleroma.Constants.as_public())
      cc = [Pleroma.Constants.as_public() | activity["cc"] || []]

      activity =
        activity
        |> Map.put("to", to)
        |> Map.put("cc", cc)
        |> Kernel.put_in(["object", "to"], to)
        |> Kernel.put_in(["object", "cc"], cc)

      {:ok, activity}
    else
      {:ok, activity}
    end
  end

  defp check_ftl_removal(activity, _hashtags), do: {:ok, activity}

  defp check_sensitive(activity) do
    {:ok, new_object} =
      Object.Updater.do_with_history(activity["object"], fn object ->
        hashtags = Object.hashtags(%Object{data: object})

        if Enum.any?(Config.get([:mrf_hashtag, :sensitive]), fn match -> match in hashtags end) do
          {:ok, Map.put(object, "sensitive", true)}
        else
          {:ok, object}
        end
      end)

    {:ok, Map.put(activity, "object", new_object)}
  end

  @impl true
  def filter(%{"type" => type, "object" => object} = activity)
      when type in ["Create", "Update"] do
    history_items =
      with %{"formerRepresentations" => %{"orderedItems" => items}} <- object do
        items
      else
        _ -> []
      end

    historical_hashtags =
      Enum.reduce(history_items, [], fn item, acc ->
        acc ++ Object.hashtags(%Object{data: item})
      end)

    hashtags = Object.hashtags(%Object{data: object}) ++ historical_hashtags

    if hashtags != [] do
      with {:ok, activity} <- check_reject(activity, hashtags),
           {:ok, activity} <-
             (if type == "Create" do
                check_ftl_removal(activity, hashtags)
              else
                {:ok, activity}
              end),
           {:ok, activity} <- check_sensitive(activity) do
        {:ok, activity}
      end
    else
      {:ok, activity}
    end
  end

  @impl true
  def filter(activity), do: {:ok, activity}

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
          description: "A list of hashtags which result in the activity being rejected.",
          suggestions: ["foo"]
        },
        %{
          key: :federated_timeline_removal,
          type: {:list, :string},
          description:
            "A list of hashtags which result in the activity being removed from federated timelines (a.k.a unlisted).",
          suggestions: ["foo"]
        },
        %{
          key: :sensitive,
          type: {:list, :string},
          description:
            "A list of hashtags which result in the activity being set as sensitive (a.k.a NSFW/R-18)",
          suggestions: ["nsfw", "r18"]
        }
      ]
    }
  end
end
