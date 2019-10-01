# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.PollView do
  use Pleroma.Web, :view

  alias Pleroma.HTML
  alias Pleroma.Web.CommonAPI.Utils

  def render("show.json", %{object: object, multiple: multiple, options: options} = params) do
    {end_time, expired} = end_time_and_expired(object)
    {options, votes_count} = options_and_votes_count(options)

    %{
      # Mastodon uses separate ids for polls, but an object can't have
      # more than one poll embedded so object id is fine
      id: to_string(object.id),
      expires_at: end_time,
      expired: expired,
      multiple: multiple,
      votes_count: votes_count,
      options: options,
      voted: voted?(params),
      emojis: Pleroma.Web.MastodonAPI.StatusView.build_emojis(object.data["emoji"])
    }
  end

  def render("show.json", %{object: object} = params) do
    case object.data do
      %{"anyOf" => options} when is_list(options) ->
        render(__MODULE__, "show.json", Map.merge(params, %{multiple: true, options: options}))

      %{"oneOf" => options} when is_list(options) ->
        render(__MODULE__, "show.json", Map.merge(params, %{multiple: false, options: options}))

      _ ->
        nil
    end
  end

  defp end_time_and_expired(object) do
    case object.data["closed"] || object.data["endTime"] do
      end_time when is_binary(end_time) ->
        end_time = NaiveDateTime.from_iso8601!(end_time)
        expired = NaiveDateTime.compare(end_time, NaiveDateTime.utc_now()) == :lt

        {Utils.to_masto_date(end_time), expired}

      _ ->
        {nil, false}
    end
  end

  defp options_and_votes_count(options) do
    Enum.map_reduce(options, 0, fn %{"name" => name} = option, count ->
      current_count = option["replies"]["totalItems"] || 0

      {%{
         title: HTML.strip_tags(name),
         votes_count: current_count
       }, current_count + count}
    end)
  end

  defp voted?(%{object: object} = opts) do
    if opts[:for] do
      existing_votes = Pleroma.Web.ActivityPub.Utils.get_existing_votes(opts[:for].ap_id, object)
      existing_votes != [] or opts[:for].ap_id == object.data["actor"]
    else
      false
    end
  end
end
