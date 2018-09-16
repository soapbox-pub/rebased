defmodule Pleroma.Web.ActivityPub.MRF.NormalizeMarkup do
  alias Pleroma.HTML

  @behaviour Pleroma.Web.ActivityPub.MRF

  @mrf_normalize_markup Application.get_env(:pleroma, :mrf_normalize_markup)

  def filter(%{"type" => activity_type} = object) when activity_type == "Create" do
    scrub_policy = Keyword.get(@mrf_normalize_markup, :scrub_policy)

    child = object["object"]

    content =
      child["content"]
      |> HTML.filter_tags(scrub_policy)

    child = Map.put(child, "content", content)

    object = Map.put(object, "object", child)

    {:ok, object}
  end

  def filter(object), do: {:ok, object}
end
