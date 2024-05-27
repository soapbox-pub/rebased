# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

# NOTE: this module is based on https://github.com/smeevil/set_locale
defmodule Pleroma.Web.Plugs.SetLocalePlug do
  import Plug.Conn, only: [get_req_header: 2, assign: 3]

  def frontend_language_cookie_name, do: "userLanguage"

  def init(_), do: nil

  def call(conn, _) do
    locales = get_locales_from_header(conn)
    first_locale = Enum.at(locales, 0, Gettext.get_locale())

    Pleroma.Web.Gettext.put_locales(locales)

    conn
    |> assign(:locale, first_locale)
    |> assign(:locales, locales)
  end

  defp get_locales_from_header(conn) do
    conn
    |> extract_preferred_language()
    |> normalize_language_codes()
    |> all_supported()
    |> Enum.uniq()
  end

  defp all_supported(locales) do
    locales
    |> Pleroma.Web.Gettext.ensure_fallbacks()
    |> Enum.filter(&supported_locale?/1)
  end

  defp normalize_language_codes(codes) do
    codes
    |> Enum.map(fn code -> Pleroma.Web.Gettext.normalize_locale(code) end)
  end

  defp extract_preferred_language(conn) do
    extract_frontend_language(conn) ++ extract_accept_language(conn)
  end

  defp extract_frontend_language(conn) do
    %{req_cookies: cookies} =
      conn
      |> Plug.Conn.fetch_cookies()

    case cookies[frontend_language_cookie_name()] do
      nil ->
        []

      fe_lang ->
        String.split(fe_lang, ",")
    end
  end

  defp extract_accept_language(conn) do
    case get_req_header(conn, "accept-language") do
      [value | _] ->
        value
        |> String.split(",")
        |> Enum.map(&parse_language_option/1)
        |> Enum.sort(&(&1.quality > &2.quality))
        |> Enum.map(& &1.tag)
        |> Enum.reject(&is_nil/1)

      _ ->
        []
    end
  end

  defp supported_locale?(locale) do
    Pleroma.Web.Gettext.supports_locale?(locale)
  end

  defp parse_language_option(string) do
    captures = Regex.named_captures(~r/^\s?(?<tag>[\w\-]+)(?:;q=(?<quality>[\d\.]+))?$/i, string)

    quality =
      case Float.parse(captures["quality"] || "1.0") do
        {val, _} -> val
        :error -> 1.0
      end

    %{tag: captures["tag"], quality: quality}
  end
end
