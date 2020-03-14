# Pleroma: A lightweight social networking server
# Copyright © 2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only
#
# This file is derived from Earmark, under the following copyright:
# Copyright © 2014 Dave Thomas, The Pragmatic Programmers
# SPDX-License-Identifier: Apache-2.0
# Upstream: https://github.com/pragdave/earmark/blob/master/lib/earmark/html_renderer.ex
defmodule Pleroma.EarmarkRenderer do
  @moduledoc false

  alias Earmark.Block
  alias Earmark.Context
  alias Earmark.HtmlRenderer
  alias Earmark.Options

  import Earmark.Inline, only: [convert: 3]
  import Earmark.Helpers.HtmlHelpers
  import Earmark.Message, only: [add_messages_from: 2, get_messages: 1, set_messages: 2]
  import Earmark.Context, only: [append: 2, set_value: 2]
  import Earmark.Options, only: [get_mapper: 1]

  @doc false
  def render(blocks, %Context{options: %Options{}} = context) do
    messages = get_messages(context)

    {contexts, html} =
      get_mapper(context.options).(
        blocks,
        &render_block(&1, put_in(context.options.messages, []))
      )
      |> Enum.unzip()

    all_messages =
      contexts
      |> Enum.reduce(messages, fn ctx, messages1 -> messages1 ++ get_messages(ctx) end)

    {put_in(context.options.messages, all_messages), html |> IO.iodata_to_binary()}
  end

  #############
  # Paragraph #
  #############
  defp render_block(%Block.Para{lnb: lnb, lines: lines, attrs: attrs}, context) do
    lines = convert(lines, lnb, context)
    add_attrs(lines, "<p>#{lines.value}</p>", attrs, [], lnb)
  end

  ########
  # Html #
  ########
  defp render_block(%Block.Html{html: html}, context) do
    {context, html}
  end

  defp render_block(%Block.HtmlComment{lines: lines}, context) do
    {context, lines}
  end

  defp render_block(%Block.HtmlOneline{html: html}, context) do
    {context, html}
  end

  #########
  # Ruler #
  #########
  defp render_block(%Block.Ruler{lnb: lnb, attrs: attrs}, context) do
    add_attrs(context, "<hr />", attrs, [], lnb)
  end

  ###########
  # Heading #
  ###########
  defp render_block(
         %Block.Heading{lnb: lnb, level: level, content: content, attrs: attrs},
         context
       ) do
    converted = convert(content, lnb, context)
    html = "<h#{level}>#{converted.value}</h#{level}>"
    add_attrs(converted, html, attrs, [], lnb)
  end

  ##############
  # Blockquote #
  ##############

  defp render_block(%Block.BlockQuote{lnb: lnb, blocks: blocks, attrs: attrs}, context) do
    {context1, body} = render(blocks, context)
    html = "<blockquote>#{body}</blockquote>"
    add_attrs(context1, html, attrs, [], lnb)
  end

  #########
  # Table #
  #########

  defp render_block(
         %Block.Table{lnb: lnb, header: header, rows: rows, alignments: aligns, attrs: attrs},
         context
       ) do
    {context1, html} = add_attrs(context, "<table>", attrs, [], lnb)
    context2 = set_value(context1, html)

    context3 =
      if header do
        append(add_trs(append(context2, "<thead>"), [header], "th", aligns, lnb), "</thead>")
      else
        # Maybe an error, needed append(context, html)
        context2
      end

    context4 = append(add_trs(append(context3, "<tbody>"), rows, "td", aligns, lnb), "</tbody>")

    {context4, [context4.value, "</table>"]}
  end

  ########
  # Code #
  ########

  defp render_block(
         %Block.Code{lnb: lnb, language: language, attrs: attrs} = block,
         %Context{options: options} = context
       ) do
    class =
      if language, do: ~s{ class="#{code_classes(language, options.code_class_prefix)}"}, else: ""

    tag = ~s[<pre><code#{class}>]
    lines = options.render_code.(block)
    html = ~s[#{tag}#{lines}</code></pre>]
    add_attrs(context, html, attrs, [], lnb)
  end

  #########
  # Lists #
  #########

  defp render_block(
         %Block.List{lnb: lnb, type: type, blocks: items, attrs: attrs, start: start},
         context
       ) do
    {context1, content} = render(items, context)
    html = "<#{type}#{start}>#{content}</#{type}>"
    add_attrs(context1, html, attrs, [], lnb)
  end

  # format a single paragraph list item, and remove the para tags
  defp render_block(
         %Block.ListItem{lnb: lnb, blocks: blocks, spaced: false, attrs: attrs},
         context
       )
       when length(blocks) == 1 do
    {context1, content} = render(blocks, context)
    content = Regex.replace(~r{</?p>}, content, "")
    html = "<li>#{content}</li>"
    add_attrs(context1, html, attrs, [], lnb)
  end

  # format a spaced list item
  defp render_block(%Block.ListItem{lnb: lnb, blocks: blocks, attrs: attrs}, context) do
    {context1, content} = render(blocks, context)
    html = "<li>#{content}</li>"
    add_attrs(context1, html, attrs, [], lnb)
  end

  ##################
  # Footnote Block #
  ##################

  defp render_block(%Block.FnList{blocks: footnotes}, context) do
    items =
      Enum.map(footnotes, fn note ->
        blocks = append_footnote_link(note)
        %Block.ListItem{attrs: "#fn:#{note.number}", type: :ol, blocks: blocks}
      end)

    {context1, html} = render_block(%Block.List{type: :ol, blocks: items}, context)
    {context1, Enum.join([~s[<div class="footnotes">], "<hr />", html, "</div>"])}
  end

  #######################################
  # Isolated IALs are rendered as paras #
  #######################################

  defp render_block(%Block.Ial{verbatim: verbatim}, context) do
    {context, "<p>{:#{verbatim}}</p>"}
  end

  ####################
  # IDDef is ignored #
  ####################

  defp render_block(%Block.IdDef{}, context), do: {context, ""}

  #####################################
  # And here are the inline renderers #
  #####################################

  defdelegate br, to: HtmlRenderer
  defdelegate codespan(text), to: HtmlRenderer
  defdelegate em(text), to: HtmlRenderer
  defdelegate strong(text), to: HtmlRenderer
  defdelegate strikethrough(text), to: HtmlRenderer

  defdelegate link(url, text), to: HtmlRenderer
  defdelegate link(url, text, title), to: HtmlRenderer

  defdelegate image(path, alt, title), to: HtmlRenderer

  defdelegate footnote_link(ref, backref, number), to: HtmlRenderer

  # Table rows
  defp add_trs(context, rows, tag, aligns, lnb) do
    numbered_rows =
      rows
      |> Enum.zip(Stream.iterate(lnb, &(&1 + 1)))

    numbered_rows
    |> Enum.reduce(context, fn {row, lnb}, ctx ->
      append(add_tds(append(ctx, "<tr>"), row, tag, aligns, lnb), "</tr>")
    end)
  end

  defp add_tds(context, row, tag, aligns, lnb) do
    Enum.reduce(1..length(row), context, add_td_fn(row, tag, aligns, lnb))
  end

  defp add_td_fn(row, tag, aligns, lnb) do
    fn n, ctx ->
      style =
        case Enum.at(aligns, n - 1, :default) do
          :default -> ""
          align -> " style=\"text-align: #{align}\""
        end

      col = Enum.at(row, n - 1)
      converted = convert(col, lnb, set_messages(ctx, []))
      append(add_messages_from(ctx, converted), "<#{tag}#{style}>#{converted.value}</#{tag}>")
    end
  end

  ###############################
  # Append Footnote Return Link #
  ###############################

  defdelegate append_footnote_link(note), to: HtmlRenderer
  defdelegate append_footnote_link(note, fnlink), to: HtmlRenderer

  defdelegate render_code(lines), to: HtmlRenderer

  defp code_classes(language, prefix) do
    ["" | String.split(prefix || "")]
    |> Enum.map(fn pfx -> "#{pfx}#{language}" end)
    |> Enum.join(" ")
  end
end
