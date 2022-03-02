# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Gettext do
  @moduledoc """
  A module providing Internationalization with a gettext-based API.

  By using [Gettext](https://hexdocs.pm/gettext),
  your module gains a set of macros for translations, for example:

      import Pleroma.Web.Gettext

      # Simple translation
      gettext "Here is the string to translate"

      # Plural translation
      ngettext "Here is the string to translate",
               "Here are the strings to translate",
               3

      # Domain-based translation
      dgettext "errors", "Here is the error message to translate"

  See the [Gettext Docs](https://hexdocs.pm/gettext) for detailed usage.
  """
  use Gettext, otp_app: :pleroma

  def language_tag do
    # Naive implementation: HTML lang attribute uses BCP 47, which
    # uses - as a separator.
    # https://developer.mozilla.org/en-US/docs/Web/HTML/Global_attributes/lang

    Gettext.get_locale()
    |> String.replace("_", "-", global: true)
  end

  def normalize_locale(locale) do
    if is_binary(locale) do
      String.replace(locale, "-", "_")
    else
      nil
    end
  end

  def supports_locale?(locale) do
    Pleroma.Web.Gettext
    |> Gettext.known_locales()
    |> Enum.member?(locale)
  end

  def locale_or_default(locale) do
    if supports_locale?(locale) do
      locale
    else
      Gettext.get_locale()
    end
  end

  defmacro with_locale_or_default(locale, do: fun) do
    quote do
      Gettext.with_locale(Pleroma.Web.Gettext.locale_or_default(unquote(locale)), fn ->
        unquote(fun)
      end)
    end
  end
end
