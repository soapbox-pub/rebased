# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.PollView do
  use Pleroma.Web, :view

  alias Pleroma.Web.CommonAPI.Utils

  def render("show.json", %{object: object, multiple: multiple, options: options} = params) do
    {end_time, expired} = end_time_and_expired(object)
    {options, votes_count} = options_and_votes_count(options)

    poll = %{
      # Mastodon uses separate ids for polls, but an object can't have
      # more than one poll embedded so object id is fine
      id: to_string(object.id),
      expires_at: end_time,
      expired: expired,
      multiple: multiple,
      votes_count: votes_count,
      voters_count: voters_count(object),
      options: options,
      emojis: Pleroma.Web.MastodonAPI.StatusView.build_emojis(object.data["emoji"])
    }

    if params[:for] do
      # when unauthenticated Mastodon doesn't include `voted` & `own_votes` keys in response
      {voted, own_votes} = voted_and_own_votes(params, options)
      Map.merge(poll, %{voted: voted, own_votes: own_votes})
    else
      poll
    end
  end

  def render("show.json", %{object: object} = params) do
    case object.data do
      %{"anyOf" => [_ | _] = options} ->
        render(__MODULE__, "show.json", Map.merge(params, %{multiple: true, options: options}))

      %{"oneOf" => [_ | _] = options} ->
        render(__MODULE__, "show.json", Map.merge(params, %{multiple: false, options: options}))

      _ ->
        nil
    end
  end

  defp end_time_and_expired(object) do
    if object.data["closed"] do
      end_time = NaiveDateTime.from_iso8601!(object.data["closed"])
      expired = NaiveDateTime.compare(end_time, NaiveDateTime.utc_now()) == :lt

      {Utils.to_masto_date(end_time), expired}
    else
      {nil, false}
    end
  end

  defp options_and_votes_count(options) do
    Enum.map_reduce(options, 0, fn %{"name" => name} = option, count ->
      current_count = option["replies"]["totalItems"] || 0

      {%{
         title: name,
         votes_count: current_count
       }, current_count + count}
    end)
  end

  defp voters_count(%{data: %{"voters" => [_ | _] = voters}}) do
    length(voters)
  end

  defp voters_count(_), do: 0

  defp voted_and_own_votes(%{object: object} = params, options) do
    if params[:for] do
      existing_votes =
        Pleroma.Web.ActivityPub.Utils.get_existing_votes(params[:for].ap_id, object)

      voted = existing_votes != [] or params[:for].ap_id == object.data["actor"]

      own_votes =
        if voted do
          titles = Enum.map(options, & &1[:title])

          Enum.reduce(existing_votes, [], fn vote, acc ->
            data = vote |> Map.get(:object) |> Map.get(:data)
            index = Enum.find_index(titles, &(&1 == data["name"]))
            [index | acc]
          end)
        else
          []
        end

      {voted, own_votes}
    else
      {false, []}
    end
  end
end
