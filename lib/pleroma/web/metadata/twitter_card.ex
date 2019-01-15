defmodule Pleroma.Web.Metadata.Providers.TwitterCard do
  alias Pleroma.Web.Metadata.Providers.Provider

  @behaviour Provider

  @impl Provider
  def build_tags(%{activity: activity}) do
    if Enum.any?(activity.data["object"]["tag"], fn tag -> tag == "nsfw" end) or
         activity.data["object"]["attachment"] == [] do
      build_tags(nil)
    else
      case find_first_acceptable_media_type(activity) do
        "image" ->
          [{:meta, [property: "twitter:card", content: "summary_large_image"], []}]

        "audio" ->
          [{:meta, [property: "twitter:card", content: "player"], []}]

        "video" ->
          [{:meta, [property: "twitter:card", content: "player"], []}]

        _ ->
          build_tags(nil)
      end
    end
  end

  @impl Provider
  def build_tags(_) do
    [{:meta, [property: "twitter:card", content: "summary"], []}]
  end

  def find_first_acceptable_media_type(%{data: %{"object" => %{"attachment" => attachment}}}) do
    Enum.find_value(attachment, fn attachment ->
      Enum.find_value(attachment["url"], fn url ->
        Enum.find(["image", "audio", "video"], fn media_type ->
          String.starts_with?(url["mediaType"], media_type)
        end)
      end)
    end)
  end
end
