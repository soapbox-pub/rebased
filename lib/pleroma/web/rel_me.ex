# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.RelMe do
  @hackney_options [
    pool: :media,
    recv_timeout: 2_000,
    max_body: 2_000_000,
    with_body: true
  ]

  if Pleroma.Config.get(:env) == :test do
    def parse(url) when is_binary(url), do: parse_url(url)
  else
    def parse(url) when is_binary(url) do
      Cachex.fetch!(:rel_me_cache, url, fn _ ->
        {:commit, parse_url(url)}
      end)
    rescue
      e -> {:error, "Cachex error: #{inspect(e)}"}
    end
  end

  def parse(_), do: {:error, "No URL provided"}

  defp parse_url(url) do
    with {:ok, %Tesla.Env{body: html, status: status}} when status in 200..299 <-
           Pleroma.HTTP.get(url, [], adapter: @hackney_options),
         data <-
           Floki.attribute(html, "link[rel~=me]", "href") ++
             Floki.attribute(html, "a[rel~=me]", "href") do
      {:ok, data}
    end
  rescue
    e -> {:error, "Parsing error: #{inspect(e)}"}
  end

  def maybe_put_rel_me("http" <> _ = target_page, profile_urls) when is_list(profile_urls) do
    {:ok, rel_me_hrefs} = parse(target_page)

    true = Enum.any?(rel_me_hrefs, fn x -> x in profile_urls end)

    "me"
  rescue
    _ -> nil
  end

  def maybe_put_rel_me(_, _) do
    nil
  end
end
