# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
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
      String.replace(locale, "-", "_", global: true)
    else
      nil
    end
  end

  def supports_locale?(locale) do
    Pleroma.Web.Gettext
    |> Gettext.known_locales()
    |> Enum.member?(locale)
  end

  def variant?(locale), do: String.contains?(locale, "_")

  def language_for_variant(locale) do
    Enum.at(String.split(locale, "_"), 0)
  end

  def ensure_fallbacks(locales) do
    locales
    |> Enum.flat_map(fn locale ->
      others =
        other_supported_variants_of_locale(locale)
        |> Enum.filter(fn l -> not Enum.member?(locales, l) end)

      [locale] ++ others
    end)
  end

  def other_supported_variants_of_locale(locale) do
    cond do
      supports_locale?(locale) ->
        []

      variant?(locale) ->
        lang = language_for_variant(locale)
        if supports_locale?(lang), do: [lang], else: []

      true ->
        Gettext.known_locales(Pleroma.Web.Gettext)
        |> Enum.filter(fn l -> String.starts_with?(l, locale <> "_") end)
    end
  end

  def get_locales do
    Process.get({Pleroma.Web.Gettext, :locales}, [])
  end

  def is_locale_list(locales) do
    Enum.all?(locales, &is_binary/1)
  end

  def put_locales(locales) do
    if is_locale_list(locales) do
      Process.put({Pleroma.Web.Gettext, :locales}, Enum.uniq(locales))
      Gettext.put_locale(Enum.at(locales, 0, Gettext.get_locale()))
      :ok
    else
      {:error, :not_locale_list}
    end
  end

  def locale_or_default(locale) do
    if supports_locale?(locale) do
      locale
    else
      Gettext.get_locale()
    end
  end

  def with_locales_func(locales, fun) do
    prev_locales = Process.get({Pleroma.Web.Gettext, :locales})
    put_locales(locales)

    try do
      fun.()
    after
      if prev_locales do
        put_locales(prev_locales)
      else
        Process.delete({Pleroma.Web.Gettext, :locales})
        Process.delete(Gettext)
      end
    end
  end

  defmacro with_locales(locales, do: fun) do
    quote do
      Pleroma.Web.Gettext.with_locales_func(unquote(locales), fn ->
        unquote(fun)
      end)
    end
  end

  def to_locale_list(locale) when is_binary(locale) do
    locale
    |> String.split(",")
    |> Enum.filter(&supports_locale?/1)
  end

  def to_locale_list(_), do: []

  defmacro with_locale_or_default(locale, do: fun) do
    quote do
      Pleroma.Web.Gettext.with_locales_func(
        Pleroma.Web.Gettext.to_locale_list(unquote(locale))
        |> Enum.concat(Pleroma.Web.Gettext.get_locales()),
        fn ->
          unquote(fun)
        end
      )
    end
  end

  defp next_locale(locale, list) do
    index = Enum.find_index(list, fn item -> item == locale end)

    if not is_nil(index) do
      Enum.at(list, index + 1)
    else
      nil
    end
  end

  # We do not yet have a proper English translation. The "English"
  # version is currently but the fallback msgid. However, this
  # will not work if the user puts English as the first language,
  # and at the same time specifies other languages, as gettext will
  # think the English translation is missing, and call
  # handle_missing_translation functions. This may result in
  # text in other languages being shown even if English is preferred
  # by the user.
  #
  # To prevent this, we do not allow fallbacking when the current
  # locale missing a translation is English.
  defp should_fallback?(locale) do
    locale != "en"
  end

  def handle_missing_translation(locale, domain, msgctxt, msgid, bindings) do
    next = next_locale(locale, get_locales())

    if is_nil(next) or not should_fallback?(locale) do
      super(locale, domain, msgctxt, msgid, bindings)
    else
      {:ok,
       Gettext.with_locale(next, fn ->
         Gettext.dpgettext(Pleroma.Web.Gettext, domain, msgctxt, msgid, bindings)
       end)}
    end
  end

  def handle_missing_plural_translation(
        locale,
        domain,
        msgctxt,
        msgid,
        msgid_plural,
        n,
        bindings
      ) do
    next = next_locale(locale, get_locales())

    if is_nil(next) or not should_fallback?(locale) do
      super(locale, domain, msgctxt, msgid, msgid_plural, n, bindings)
    else
      {:ok,
       Gettext.with_locale(next, fn ->
         Gettext.dpngettext(
           Pleroma.Web.Gettext,
           domain,
           msgctxt,
           msgid,
           msgid_plural,
           n,
           bindings
         )
       end)}
    end
  end
end
