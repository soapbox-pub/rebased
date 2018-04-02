defmodule Pleroma.Web.TwitterAPI.ActivityView do
  use Pleroma.Web, :view
  alias Pleroma.Web.CommonAPI.Utils
  alias Pleroma.User
  alias Pleroma.Web.TwitterAPI.UserView
  alias Pleroma.Web.TwitterAPI.ActivityView
  alias Pleroma.Web.TwitterAPI.TwitterAPI
  alias Pleroma.Web.TwitterAPI.Representers.ObjectRepresenter
  alias Pleroma.Activity
  alias Pleroma.Object
  alias Pleroma.Repo
  alias Pleroma.Formatter

  import Ecto.Query

  defp query_context_ids(contexts) do
    query = from o in Object,
      where: fragment("(?)->>'id' = ANY(?)", o.data, ^contexts)

    Repo.all(query)
  end

  defp collect_context_ids(activities) do
    contexts = activities
    |> Enum.map(fn(%{data: data}) ->
      data["context"]
    end)
    |> Enum.filter(&(&1))
    |> query_context_ids()
    |> Enum.reduce(%{}, fn(%{data: %{"id" => ap_id}, id: id}, acc) ->
      Map.put(acc, ap_id, id)
    end)
  end

  defp get_context_id(%{data: %{"context" => nil}}, _), do: nil
  defp get_context_id(%{data: %{"context" => context}}, options) do
    cond do
      id = options[:context_ids][context] -> id
      true -> TwitterAPI.context_to_conversation_id(context)
    end
  end
  defp get_context_id(_, _), do: nil

  def render("index.json", opts) do
    context_ids = collect_context_ids(opts.activities)
    opts = opts
    |> Map.put(:context_ids, context_ids)

    render_many(
      opts.activities,
      ActivityView,
      "activity.json",
      opts
    )
  end

  def render("activity.json", %{activity: %{data: %{"type" => "Delete"}} = activity} = opts) do
    user = User.get_cached_by_ap_id(activity.data["actor"])
    created_at = activity.data["published"] |> Utils.date_to_asctime()

    %{
      "id" => activity.id,
      "uri" => activity.data["object"],
      "user" => UserView.render("show.json", %{user: user, for: opts[:for]}),
      "attentions" => [],
      "statusnet_html" => "deleted notice {{tag",
      "text" => "deleted notice {{tag",
      "is_local" => activity.local,
      "is_post_verb" => false,
      "created_at" => created_at,
      "in_reply_to_status_id" => nil,
      "external_url" => activity.data["id"],
      "activity_type" => "delete"
    }
  end

  def render("activity.json", %{activity: %{data: %{"type" => "Follow"}} = activity} = opts) do
    user = User.get_cached_by_ap_id(activity.data["actor"])
    created_at = activity.data["published"] || DateTime.to_iso8601(activity.inserted_at)
    created_at = created_at |> Utils.date_to_asctime()

    followed = User.get_cached_by_ap_id(activity.data["object"])
    text = "#{user.nickname} started following #{followed.nickname}"

    %{
      "id" => activity.id,
      "user" => UserView.render("show.json", %{user: user, for: opts[:for]}),
      "attentions" => [],
      "statusnet_html" => text,
      "text" => text,
      "is_local" => activity.local,
      "is_post_verb" => false,
      "created_at" => created_at,
      "in_reply_to_status_id" => nil,
      "external_url" => activity.data["id"],
      "activity_type" => "follow"
    }
  end

  def render("activity.json", %{activity: %{data: %{"type" => "Announce"}} = activity} = opts) do
    user = User.get_by_ap_id(activity.data["actor"])
    created_at = activity.data["published"] |> Utils.date_to_asctime()
    announced_activity = Activity.get_create_activity_by_object_ap_id(activity.data["object"])

    text = "#{user.nickname} retweeted a status."

    retweeted_status = render("activity.json", Map.merge(opts, %{activity: announced_activity}))

    %{
      "id" => activity.id,
      "user" => UserView.render("show.json", %{user: user, for: opts[:for]}),
      "statusnet_html" => text,
      "text" => text,
      "is_local" => activity.local,
      "is_post_verb" => false,
      "uri" => "tag:#{activity.data["id"]}:objectType=note",
      "created_at" => created_at,
      "retweeted_status" => retweeted_status,
      "statusnet_conversation_id" => get_context_id(announced_activity, opts),
      "external_url" => activity.data["id"],
      "activity_type" => "repeat"
    }
  end

  def render("activity.json", %{activity: %{data: %{"type" => "Like"}} = activity} = opts) do
    user = User.get_cached_by_ap_id(activity.data["actor"])
    liked_activity = Activity.get_create_activity_by_object_ap_id(activity.data["object"])

    created_at =
      activity.data["published"]
      |> Utils.date_to_asctime()

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

  def render(
        "activity.json",
        %{activity: %{data: %{"type" => "Create", "object" => object}} = activity} = opts
      ) do
    actor = get_in(activity.data, ["actor"])
    user = User.get_cached_by_ap_id(actor)

    created_at = object["published"] |> Utils.date_to_asctime()
    like_count = object["like_count"] || 0
    announcement_count = object["announcement_count"] || 0
    favorited = opts[:for] && opts[:for].ap_id in (object["likes"] || [])
    repeated = opts[:for] && opts[:for].ap_id in (object["announcements"] || [])

    attentions =
      activity.recipients
      |> Enum.map(fn ap_id -> User.get_cached_by_ap_id(ap_id) end)
      |> Enum.filter(& &1)
      |> Enum.map(fn user -> UserView.render("show.json", %{user: user, for: opts[:for]}) end)

    conversation_id = get_context_id(activity, opts)

    tags = activity.data["object"]["tag"] || []
    possibly_sensitive = activity.data["object"]["sensitive"] || Enum.member?(tags, "nsfw")

    tags = if possibly_sensitive, do: Enum.uniq(["nsfw" | tags]), else: tags

    summary = activity.data["object"]["summary"]
    content = object["content"]

    content =
      if !!summary and summary != "" do
        "<span>#{activity.data["object"]["summary"]}</span><br />#{content}</span>"
      else
        content
      end

    html =
      HtmlSanitizeEx.basic_html(content)
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
    else
      _e -> nil
    end
  end
end
