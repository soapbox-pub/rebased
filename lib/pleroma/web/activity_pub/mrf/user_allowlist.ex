defmodule Pleroma.Web.ActivityPub.MRF.UserAllowListPolicy do
  alias Pleroma.Config

  @behaviour Pleroma.Web.ActivityPub.MRF

  defp filter_by_list(object, []), do: {:ok, object}

  defp filter_by_list(%{"actor" => actor} = object, allow_list) do
    if actor in allow_list do
      {:ok, object}
    else
      {:reject, nil}
    end
  end

  @impl true
  def filter(object) do
    actor_info = URI.parse(object["actor"])
    allow_list = Config.get([:mrf_user_allowlist, String.to_atom(actor_info.host)], [])

    filter_by_list(object, allow_list)
  end
end
