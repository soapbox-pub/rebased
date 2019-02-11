# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.RelMe do
  @hackney_options [
    pool: :media,
    timeout: 2_000,
    recv_timeout: 2_000,
    max_body: 2_000_000
  ]

  def parse(nil), do: {:error, "No URL provided"}

  if Mix.env() == :test do
    def parse(url), do: parse_url(url)
  else
    def parse(url) do
      Cachex.fetch!(:rel_me_cache, url, fn _ ->
        {:commit, parse_url(url)}
      end)
    rescue
      e -> {:error, "Cachex error: #{inspect(e)}"}
    end
  end

  defp parse_url(url) do
    {:ok, %Tesla.Env{body: html}} = Pleroma.HTTP.get(url, [], adapter: @hackney_options)

    Floki.attribute(html, "link[rel=me]", "href") ++ Floki.attribute(html, "a[rel=me]", "href")
  rescue
    e -> {:error, "Parsing error: #{inspect(e)}"}
  end

  def maybe_put_rel_me("http" <> _ = target_page, urls) when not is_nil(urls) do
    if Enum.any?(parse(target_page), fn x -> x in urls end) do
      "rel=\"me\" "
    else
      ""
    end
  end

  def maybe_put_rel_me(_, _) do
    ""
  end
end
