# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Feed.FeedView do
  use Phoenix.HTML
  use Pleroma.Web, :view

  alias Pleroma.Formatter
  alias Pleroma.Object
  alias Pleroma.User
  alias Pleroma.Web.Gettext
  alias Pleroma.Web.MediaProxy

  require Pleroma.Constants

  @days ~w(Mon Tue Wed Thu Fri Sat Sun)
  @months ~w(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec)

  def prepare_activity(activity, opts \\ []) do
    object = Object.normalize(activity, fetch: false)

    actor =
      if opts[:actor] do
        Pleroma.User.get_cached_by_ap_id(activity.actor)
      end

    %{
      activity: activity,
      object: object,
      data: Map.get(object, :data),
      actor: actor
    }
  end

  def most_recent_update(activities) do
    with %{updated_at: updated_at} <- List.first(activities) do
      to_rfc3339(updated_at)
    end
  end

  def most_recent_update(activities, user, :atom) do
    (List.first(activities) || user).updated_at
    |> to_rfc3339()
  end

  def most_recent_update(activities, user, :rss) do
    (List.first(activities) || user).updated_at
    |> to_rfc2822()
  end

  def feed_logo do
    case Pleroma.Config.get([:feed, :logo]) do
      nil ->
        "#{Pleroma.Web.Endpoint.url()}/static/logo.svg"

      logo ->
        "#{Pleroma.Web.Endpoint.url()}#{logo}"
    end
    |> MediaProxy.url()
  end

  def email(user) do
    user.nickname <> "@" <> Pleroma.Web.Endpoint.host()
  end

  def logo(user) do
    user
    |> User.avatar_url()
    |> MediaProxy.url()
  end

  def last_activity(activities), do: List.last(activities)

  def activity_title(%{"content" => content, "summary" => summary} = data, opts \\ %{}) do
    title =
      cond do
        summary != "" -> summary
        content != "" -> activity_content(data)
        true -> "a post"
      end

    title
    |> Pleroma.Web.Metadata.Utils.scrub_html()
    |> Pleroma.Emoji.Formatter.demojify()
    |> Formatter.truncate(opts[:max_length], opts[:omission])
  end

  def activity_description(data) do
    content = activity_content(data)
    summary = data["summary"]

    cond do
      content != "" -> escape(content)
      summary != "" -> escape(summary)
      true -> escape(data["type"])
    end
  end

  def activity_content(%{"content" => content}) do
    content
    |> String.replace(~r/[\n\r]/, "")
  end

  def activity_content(_), do: ""

  def activity_context(activity), do: escape(activity.data["context"])

  def attachment_href(attachment) do
    attachment["url"]
    |> hd()
    |> Map.get("href")
  end

  def attachment_type(attachment) do
    attachment["url"]
    |> hd()
    |> Map.get("mediaType")
  end

  def get_href(id) do
    with %Object{data: %{"external_url" => external_url}} <- Object.get_cached_by_ap_id(id) do
      external_url
    else
      _e -> id
    end
  end

  def escape(html) do
    html
    |> html_escape()
    |> safe_to_string()
  end

  @spec to_rfc3339(String.t() | NativeDateTime.t()) :: String.t()
  def to_rfc3339(date) when is_binary(date) do
    date
    |> Timex.parse!("{ISO:Extended}")
    |> to_rfc3339()
  end

  def to_rfc3339(nd) do
    nd
    |> Timex.to_datetime()
    |> Timex.format!("{RFC3339}")
  end

  @spec to_rfc2822(String.t() | DateTime.t() | NativeDateTime.t()) :: String.t()
  def to_rfc2822(datestr) when is_binary(datestr) do
    datestr
    |> Timex.parse!("{ISO:Extended}")
    |> to_rfc2822()
  end

  def to_rfc2822(%DateTime{} = date) do
    date
    |> DateTime.to_naive()
    |> NaiveDateTime.to_erl()
    |> rfc2822_from_erl()
  end

  def to_rfc2822(nd) do
    nd
    |> Timex.to_datetime()
    |> DateTime.to_naive()
    |> NaiveDateTime.to_erl()
    |> rfc2822_from_erl()
  end

  @doc """
  Builds a RFC2822 timestamp from an Erlang timestamp
  [RFC2822 3.3 - Date and Time Specification](https://tools.ietf.org/html/rfc2822#section-3.3)
  This function always assumes the Erlang timestamp is in Universal time, not Local time
  """
  def rfc2822_from_erl({{year, month, day} = date, {hour, minute, second}}) do
    day_name = Enum.at(@days, :calendar.day_of_the_week(date) - 1)
    month_name = Enum.at(@months, month - 1)

    date_part = "#{day_name}, #{day} #{month_name} #{year}"
    time_part = "#{pad(hour)}:#{pad(minute)}:#{pad(second)}"

    date_part <> " " <> time_part <> " +0000"
  end

  defp pad(num) do
    num
    |> Integer.to_string()
    |> String.pad_leading(2, "0")
  end
end
