defmodule Pleroma.Web.ActivityPub.MRF.AntiDuplicationPolicy do
  @moduledoc "Prevents messages with the exact same content from being posted repeatedly, regardless of its source."
  @behaviour Pleroma.Web.ActivityPub.MRF.Policy

  @cachex Pleroma.Config.get([:cachex, :provider], Cachex)
  @cache :anti_duplication_mrf_cache

  @impl true
  def filter(%{"type" => "Create", "object" => %{"content" => content}} = activity)
      when is_binary(content) do
    ttl = Pleroma.Config.get([:mrf_anti_duplication, :ttl], :timer.minutes(1))
    min_length = Pleroma.Config.get([:mrf_anti_duplication, :min_length], 50)

    if String.length(content) >= min_length do
      # We use SHA1 because it's faster and we don't need cryptographic security here.
      key = :crypto.hash(:sha, content) |> Base.encode64(case: :lower)

      case @cachex.exists?(@cache, key) do
        {:ok, true} ->
          @cachex.expire(@cache, key, ttl)
          {:reject, "[AntiDuplicationPolicy] Message is a duplicate"}

        {:ok, false} ->
          @cachex.put(@cache, key, true, ttl: ttl)
          {:ok, activity}
      end
    else
      {:ok, activity}
    end
  end

  def filter(object) do
    {:ok, object}
  end

  @impl true
  def describe, do: {:ok, %{}}
end
