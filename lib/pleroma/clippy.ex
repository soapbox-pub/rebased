# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Clippy do
  @moduledoc false

  # No software is complete until they have a Clippy implementation.
  # A ballmer peak _may_ be required to change this module.

  def tip do
    tips()
    |> Enum.random()
    |> puts()
  end

  def tips do
    host = Pleroma.Config.get([Pleroma.Web.Endpoint, :url, :host])

    [
      "“πλήρωμα” is “pleroma” in greek",
      "For an extended Pleroma Clippy Experience, use the “Redmond” themes in Pleroma FE settings",
      "Staff accounts and MRF policies of Pleroma instances are disclosed on the NodeInfo endpoints for easy transparency!\n
- https://catgirl.science/misc/nodeinfo.lua?#{host}
- https://fediverse.network/#{host}/federation",
      "Pleroma can federate to the Dark Web!\n
- Tor: https://git.pleroma.social/pleroma/pleroma/wikis/Easy%20Onion%20Federation%20(Tor)
- i2p: https://git.pleroma.social/pleroma/pleroma/wikis/I2p%20federation",
      "Lists of Pleroma instances:\n\n- http://distsn.org/pleroma-instances.html\n- https://fediverse.network/pleroma\n- https://the-federation.info/pleroma",
      "Pleroma uses the LitePub protocol - https://litepub.social",
      "To receive more federated posts, subscribe to relays!\n
- How-to: https://git.pleroma.social/pleroma/pleroma/wikis/Admin%20tasks#relay-managment
- Relays: https://fediverse.network/activityrelay"
    ]
  end

  @spec puts(String.t() | [[IO.ANSI.ansicode() | String.t(), ...], ...]) :: nil
  def puts(text_or_lines) do
    import IO.ANSI

    lines =
      if is_binary(text_or_lines) do
        String.split(text_or_lines, ~r/\n/)
      else
        text_or_lines
      end

    longest_line_size =
      lines
      |> Enum.map(&charlist_count_text/1)
      |> Enum.sort(&>=/2)
      |> List.first()

    pad_text = longest_line_size

    pad =
      for(_ <- 1..pad_text, do: "_")
      |> Enum.join("")

    pad_spaces =
      for(_ <- 1..pad_text, do: " ")
      |> Enum.join("")

    spaces = "      "

    pre_lines = [
      "  /  \\#{spaces}  _#{pad}___",
      "  |  |#{spaces} / #{pad_spaces}   \\"
    ]

    for l <- pre_lines do
      IO.puts(l)
    end

    clippy_lines = [
      "  #{bright()}@  @#{reset()}#{spaces} ",
      "  || ||#{spaces}",
      "  || ||   <--",
      "  |\\_/|      ",
      "  \\___/      "
    ]

    noclippy_line = "             "

    env = %{
      max_size: pad_text,
      pad: pad,
      pad_spaces: pad_spaces,
      spaces: spaces,
      pre_lines: pre_lines,
      noclippy_line: noclippy_line
    }

    # surrond one/five line clippy with blank lines around to not fuck up the layout
    #
    # yes this fix sucks but it's good enough, have you ever seen a release of windows
    # without some butched features anyway?
    lines =
      if length(lines) == 1 or length(lines) == 5 do
        [""] ++ lines ++ [""]
      else
        lines
      end

    clippy_line(lines, clippy_lines, env)
  rescue
    e ->
      IO.puts("(Clippy crashed, sorry: #{inspect(e)})")
      IO.puts(text_or_lines)
  end

  defp clippy_line([line | lines], [prefix | clippy_lines], env) do
    IO.puts([prefix <> "| ", rpad_line(line, env.max_size)])
    clippy_line(lines, clippy_lines, env)
  end

  # more text lines but clippy's complete
  defp clippy_line([line | lines], [], env) do
    IO.puts([env.noclippy_line, "| ", rpad_line(line, env.max_size)])

    if lines == [] do
      IO.puts(env.noclippy_line <> "\\_#{env.pad}___/")
    end

    clippy_line(lines, [], env)
  end

  # no more text lines but clippy's not complete
  defp clippy_line([], [clippy | clippy_lines], env) do
    if env.pad do
      IO.puts(clippy <> "\\_#{env.pad}___/")
      clippy_line([], clippy_lines, %{env | pad: nil})
    else
      IO.puts(clippy)
      clippy_line([], clippy_lines, env)
    end
  end

  defp clippy_line(_, _, _) do
  end

  defp rpad_line(line, max) do
    pad = max - (charlist_count_text(line) - 2)
    pads = Enum.join(for(_ <- 1..pad, do: " "))
    [IO.ANSI.format(line), pads <> " |"]
  end

  defp charlist_count_text(line) do
    if is_list(line) do
      text = Enum.join(Enum.filter(line, &is_binary/1))
      String.length(text)
    else
      String.length(line)
    end
  end
end
