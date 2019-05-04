defmodule Pleroma.Web.Metadata.Providers.RelMe do
  alias Pleroma.Web.Metadata.Providers.Provider
  @behaviour Provider

  @impl Provider
  def build_tags(%{user: user}) do
    (Floki.attribute(user.bio, "link[rel~=me]", "href") ++
       Floki.attribute(user.bio, "a[rel~=me]", "href"))
    |> Enum.map(fn link ->
      {:link, [rel: "me", href: link], []}
    end)
  end
end
