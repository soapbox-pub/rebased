# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.PleromaAPI.EventView do
  use Pleroma.Web, :view

  alias Pleroma.Activity
  alias Pleroma.Object
  alias Pleroma.User
  alias Pleroma.Web.CommonAPI
  alias Pleroma.Web.MastodonAPI.AccountView

  def render("participation_requests.json", %{activities: activities} = opts) do
    render_many(
      activities,
      __MODULE__,
      "participation_request.json",
      Map.delete(opts, :activities)
    )
  end

  def render("participation_request.json", %{activity: activity} = opts) do
    user = CommonAPI.get_user(activity.data["actor"])

    %{
      account:
        AccountView.render("show.json", %{
          user: user,
          for: opts[:for]
        }),
      participation_message: activity.data["participationMessage"]
    }
  end

  def render("show.ics", %{activity: %Activity{actor: actor_ap_id} = activity}) do
    with %Object{} = object <- Object.normalize(activity, fetch: false),
         %User{} = user <- User.get_cached_by_ap_id(actor_ap_id) do
      event = %ICalendar.Event{
        summary: object.data["name"],
        dtstart: object.data["startTime"] |> get_date,
        dtend: object.data["endTime"] |> get_date,
        description: Pleroma.HTML.strip_tags(object.data["content"]),
        uid: object.id,
        url: object.data["url"] || object.data["id"],
        geo: get_coords(object),
        location: get_location(object),
        organizer: Pleroma.HTML.strip_tags(user.name || user.nickname)
      }

      %ICalendar{events: [event]}
    end
  end

  defp get_coords(%Object{
         data: %{"location" => %{"longitude" => longitude, "latitude" => latitude}}
       }) do
    {latitude, longitude}
  end

  defp get_coords(_) do
    nil
  end

  defp get_location(%Object{
         data: %{"location" => %{"name" => description, "address" => %{} = address}}
       }) do
    String.trim(
      "#{description} #{address["streetAddress"]} #{address["postalCode"]} #{address["addressLocality"]} #{address["addressRegion"]} #{address["addressCountry"]}"
    )
  end

  defp get_location(_) do
    nil
  end

  defp get_date(date) when is_binary(date) do
    {:ok, date, _} = DateTime.from_iso8601(date)

    date
  end

  defp get_date(_) do
    nil
  end
end
