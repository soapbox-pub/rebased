# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.MRF.InlineQuotePolicy do
  @moduledoc "Force a quote line into the message content."
  @behaviour Pleroma.Web.ActivityPub.MRF.Policy

  defp build_inline_quote(prefix, url) do
    "<span class=\"quote-inline\"><br/><br/>#{prefix}: <a href=\"#{url}\">#{url}</a></span>"
  end

  defp has_inline_quote?(content, quote_url) do
    cond do
      # Does the quote URL exist in the content?
      content =~ quote_url -> true
      # Does the content already have a .quote-inline span?
      content =~ "<span class=\"quote-inline\">" -> true
      # No inline quote found
      true -> false
    end
  end

  defp filter_object(%{"quoteUrl" => quote_url} = object) do
    content = object["content"] || ""

    if has_inline_quote?(content, quote_url) do
      object
    else
      prefix = Pleroma.Config.get([:mrf_inline_quote, :prefix])

      content =
        if String.ends_with?(content, "</p>"),
          do:
            String.trim_trailing(content, "</p>") <>
              build_inline_quote(prefix, quote_url) <> "</p>",
          else: content <> build_inline_quote(prefix, quote_url)

      Map.put(object, "content", content)
    end
  end

  @impl true
  def filter(%{"object" => %{"quoteUrl" => _} = object} = activity) do
    {:ok, Map.put(activity, "object", filter_object(object))}
  end

  @impl true
  def filter(object), do: {:ok, object}

  @impl true
  def describe, do: {:ok, %{}}

  @impl true
  def config_description do
    %{
      key: :mrf_inline_quote,
      related_policy: "Pleroma.Web.ActivityPub.MRF.InlineQuotePolicy",
      label: "MRF Inline Quote",
      description: "Force quote post URLs inline",
      children: [
        %{
          key: :prefix,
          type: :string,
          description: "Prefix before the link",
          suggestions: ["RT", "QT", "RE", "RN"]
        }
      ]
    }
  end
end
