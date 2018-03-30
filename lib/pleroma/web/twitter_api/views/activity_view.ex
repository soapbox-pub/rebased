defmodule Pleroma.Web.TwitterAPI.ActivityView do
  use Pleroma.Web, :view
  alias Pleroma.Web.CommonAPI.Utils
  alias Pleroma.User
  alias Pleroma.Web.TwitterAPI.UserView
  alias Pleroma.Web.TwitterAPI.TwitterAPI
  alias Pleroma.Web.TwitterAPI.Representers.ObjectRepresenter
  alias Pleroma.Activity
  alias Pleroma.Formatter

  def render("activity.json", %{activity: %{data: %{"type" => "Like"}} = activity} = opts) do
    user = User.get_cached_by_ap_id(activity.data["actor"])
    liked_activity = Activity.get_create_activity_by_object_ap_id(activity.data["object"])
    created_at = activity.data["published"]
    |> Utils.date_to_asctime

    text = "#{user.nickname} favorited a status."

    %{
      "id" => activity.id,
      "user" => UserView.render("show.json", %{user: user, for: opts[:for]}),
      "statusnet_html" => text,
      "text" => text,
      "is_local" => activity.local,
      "is_post_verb" => false,
      "uri" => "tag:#{activity.data["id"]}:objectType=Favourite",
      "created_at" => created_at,
      "in_reply_to_status_id" => liked_activity.id,
      "external_url" => activity.data["id"],
      "activity_type" => "like"
    }
  end

  def render("activity.json", %{activity: %{data: %{"type" => "Create", "object" => object}} = activity} = opts) do
    actor = get_in(activity.data, ["actor"])
    user = User.get_cached_by_ap_id(actor)

    created_at = object["published"] |> Utils.date_to_asctime
    like_count = object["like_count"] || 0
    announcement_count = object["announcement_count"] || 0
    favorited = opts[:for] && opts[:for].ap_id in (object["likes"] || [])
    repeated = opts[:for] && opts[:for].ap_id in (object["announcements"] || [])

    attentions = activity.recipients
    |> Enum.map(fn (ap_id) -> User.get_cached_by_ap_id(ap_id) end)
    |> Enum.filter(&(&1))
    |> Enum.map(fn (user) -> UserView.render("show.json", %{user: user, for: opts[:for]}) end)

    conversation_id = conversation_id(activity)

    tags = activity.data["object"]["tag"] || []
    possibly_sensitive = activity.data["object"]["sensitive"] || Enum.member?(tags, "nsfw")

    tags = if possibly_sensitive, do: Enum.uniq(["nsfw" | tags]), else: tags

    summary = activity.data["object"]["summary"]
    content = object["content"]
    content = if !!summary and summary != "" do
      "<span>#{activity.data["object"]["summary"]}</span><br />#{content}</span>"
    else
      content
    end

    html = HtmlSanitizeEx.basic_html(content)
    |> Formatter.emojify(object["emoji"])

    %{
      "id" => activity.id,
      "uri" => activity.data["object"]["id"],
      "user" => UserView.render("show.json", %{user: user, for: opts[:for]}),
      "statusnet_html" => html,
      "text" => HtmlSanitizeEx.strip_tags(content),
      "is_local" => activity.local,
      "is_post_verb" => true,
      "created_at" => created_at,
      "in_reply_to_status_id" => object["inReplyToStatusId"],
      "statusnet_conversation_id" => conversation_id,
      "attachments" => (object["attachment"] || []) |> ObjectRepresenter.enum_to_list(opts),
      "attentions" => attentions,
      "fave_num" => like_count,
      "repeat_num" => announcement_count,
      "favorited" => !!favorited,
      "repeated" => !!repeated,
      "external_url" => object["external_url"] || object["id"],
      "tags" => tags,
      "activity_type" => "post",
      "possibly_sensitive" => possibly_sensitive
    }
  end

  defp conversation_id(activity) do
    with context when not is_nil(context) <- activity.data["context"] do
      TwitterAPI.context_to_conversation_id(context)
    else _e -> nil
    end
  end
end
