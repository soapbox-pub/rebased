# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Plugs.SetLocalePlugTest do
  use ExUnit.Case, async: true
  use Plug.Test

  alias Pleroma.Web.Plugs.SetLocalePlug
  alias Plug.Conn

  test "default locale is `en`" do
    conn =
      :get
      |> conn("/cofe")
      |> SetLocalePlug.call([])

    assert "en" == Gettext.get_locale()
    assert %{locale: "en"} = conn.assigns
  end

  test "use supported locale from `accept-language`" do
    conn =
      :get
      |> conn("/cofe")
      |> Conn.put_req_header(
        "accept-language",
        "ru, fr-CH, fr;q=0.9, en;q=0.8, *;q=0.5"
      )
      |> SetLocalePlug.call([])

    assert "ru" == Gettext.get_locale()
    assert %{locale: "ru"} = conn.assigns
  end

  test "fallback to the general language if a variant is not supported" do
    conn =
      :get
      |> conn("/cofe")
      |> Conn.put_req_header(
        "accept-language",
        "ru-CA;q=0.9, en;q=0.8, *;q=0.5"
      )
      |> SetLocalePlug.call([])

    assert "ru" == Gettext.get_locale()
    assert %{locale: "ru"} = conn.assigns
  end

  test "use supported locale with specifiers from `accept-language`" do
    conn =
      :get
      |> conn("/cofe")
      |> Conn.put_req_header(
        "accept-language",
        "zh-Hans;q=0.9, en;q=0.8, *;q=0.5"
      )
      |> SetLocalePlug.call([])

    assert "zh_Hans" == Gettext.get_locale()
    assert %{locale: "zh_Hans"} = conn.assigns
  end

  test "it assigns all supported locales" do
    conn =
      :get
      |> conn("/cofe")
      |> Conn.put_req_header(
        "accept-language",
        "ru, fr-CH, fr;q=0.9, en;q=0.8, x-unsupported;q=0.8, *;q=0.5"
      )
      |> SetLocalePlug.call([])

    assert "ru" == Gettext.get_locale()
    assert %{locale: "ru", locales: ["ru", "fr", "en"]} = conn.assigns
  end

  test "it assigns all supported locales in cookie" do
    conn =
      :get
      |> conn("/cofe")
      |> put_req_cookie(SetLocalePlug.frontend_language_cookie_name(), "zh-Hans,uk,zh-Hant")
      |> Conn.put_req_header(
        "accept-language",
        "ru, fr-CH, fr;q=0.9, en;q=0.8, x-unsupported;q=0.8, *;q=0.5"
      )
      |> SetLocalePlug.call([])

    assert "zh_Hans" == Gettext.get_locale()

    assert %{locale: "zh_Hans", locales: ["zh_Hans", "uk", "zh_Hant", "ru", "fr", "en"]} =
             conn.assigns
  end

  test "fallback to some variant of the language if the unqualified language is not supported" do
    conn =
      :get
      |> conn("/cofe")
      |> Conn.put_req_header(
        "accept-language",
        "zh;q=0.9, en;q=0.8, *;q=0.5"
      )
      |> SetLocalePlug.call([])

    assert "zh_" <> _ = Gettext.get_locale()
    assert %{locale: "zh_" <> _} = conn.assigns
  end

  test "use supported locale from cookie" do
    conn =
      :get
      |> conn("/cofe")
      |> put_req_cookie(SetLocalePlug.frontend_language_cookie_name(), "zh-Hans")
      |> Conn.put_req_header(
        "accept-language",
        "ru, fr-CH, fr;q=0.9, en;q=0.8, *;q=0.5"
      )
      |> SetLocalePlug.call([])

    assert "zh_Hans" == Gettext.get_locale()
    assert %{locale: "zh_Hans"} = conn.assigns
  end

  test "fallback to supported locale from `accept-language` if locale in cookie not supported" do
    conn =
      :get
      |> conn("/cofe")
      |> put_req_cookie(SetLocalePlug.frontend_language_cookie_name(), "x-nonexist")
      |> Conn.put_req_header(
        "accept-language",
        "ru, fr-CH, fr;q=0.9, en;q=0.8, *;q=0.5"
      )
      |> SetLocalePlug.call([])

    assert "ru" == Gettext.get_locale()
    assert %{locale: "ru"} = conn.assigns
  end

  test "fallback to default if nothing is supported" do
    conn =
      :get
      |> conn("/cofe")
      |> put_req_cookie(SetLocalePlug.frontend_language_cookie_name(), "x-nonexist")
      |> Conn.put_req_header(
        "accept-language",
        "x-nonexist"
      )
      |> SetLocalePlug.call([])

    assert "en" == Gettext.get_locale()
    assert %{locale: "en"} = conn.assigns
  end

  test "use default locale if locale from `accept-language` is not supported" do
    conn =
      :get
      |> conn("/cofe")
      |> Conn.put_req_header("accept-language", "tlh")
      |> SetLocalePlug.call([])

    assert "en" == Gettext.get_locale()
    assert %{locale: "en"} = conn.assigns
  end
end
