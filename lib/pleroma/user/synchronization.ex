# Pleroma: A lightweight social networking server
# Copyright © 2017-2018 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.User.Synchronization do
  alias Pleroma.HTTP
  alias Pleroma.User

  @spec call([User.t()], map(), keyword()) :: {User.t(), map()}
  def call(users, errors, opts \\ []) do
    do_call(users, errors, opts)
  end

  defp do_call([user | []], errors, opts) do
    updated = fetch_counters(user, errors, opts)
    {user, updated}
  end

  defp do_call([user | others], errors, opts) do
    updated = fetch_counters(user, errors, opts)
    do_call(others, updated, opts)
  end

  defp fetch_counters(user, errors, opts) do
    %{host: host} = URI.parse(user.ap_id)

    info = %{}
    {following, errors} = fetch_counter(user.ap_id <> "/following", host, errors, opts)
    info = if following, do: Map.put(info, :following_count, following), else: info

    {followers, errors} = fetch_counter(user.ap_id <> "/followers", host, errors, opts)
    info = if followers, do: Map.put(info, :follower_count, followers), else: info

    User.set_info_cache(user, info)
    errors
  end

  defp available_domain?(domain, errors, opts) do
    max_retries = Keyword.get(opts, :max_retries, 3)
    not (Map.has_key?(errors, domain) && errors[domain] >= max_retries)
  end

  defp fetch_counter(url, host, errors, opts) do
    with true <- available_domain?(host, errors, opts),
         {:ok, %{body: body, status: code}} when code in 200..299 <-
           HTTP.get(
             url,
             [{:Accept, "application/activity+json"}]
           ),
         {:ok, data} <- Jason.decode(body) do
      {data["totalItems"], errors}
    else
      false ->
        {nil, errors}

      _ ->
        {nil, Map.update(errors, host, 1, &(&1 + 1))}
    end
  end
end
