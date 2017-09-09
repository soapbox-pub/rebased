defmodule Pleroma.Web.MastodonAPI.StatusView do
  use Pleroma.Web, :view
  alias Pleroma.Web.MastodonAPI.{AccountView, StatusView}
  alias Pleroma.User

  def render("index.json", opts) do
    render_many(opts.activities, StatusView, "status.json", opts)
  end

  def render("status.json", %{activity: %{data: %{"object" => object}} = activity} = opts) do
    user = User.get_cached_by_ap_id(activity.data["actor"])

    like_count = object["like_count"] || 0
    announcement_count = object["announcement_count"] || 0

    tags = object["tag"] || []
    sensitive = Enum.member?(tags, "nsfw")

    mentions = activity.data["to"]
    |> Enum.map(fn (ap_id) -> User.get_cached_by_ap_id(ap_id) end)
    |> Enum.filter(&(&1))
    |> Enum.map(fn (user) -> AccountView.render("mention.json", %{user: user}) end)

    repeated = opts[:for] && opts[:for].ap_id in (object["announcements"] || [])
    favorited = opts[:for] && opts[:for].ap_id in (object["likes"] || [])

    %{
      id: activity.id,
      uri: object["id"],
      url: object["external_url"],
      account: AccountView.render("account.json", %{user: user}),
      in_reply_to_id: object["inReplyToStatusId"],
      in_reply_to_account_id: nil,
      reblog: nil,
      content: HtmlSanitizeEx.basic_html(object["content"]),
      created_at: object["published"],
      reblogs_count: announcement_count,
      favourites_count: like_count,
      reblogged: !!repeated,
      favourited: !!favorited,
      muted: false,
      sensitive: sensitive,
      spoiler_text: "",
      visibility: "public",
      media_attachments: [], # fix
      mentions: mentions,
      tags: [], # fix,
      application: nil,
      language: nil
    }
  end
end
