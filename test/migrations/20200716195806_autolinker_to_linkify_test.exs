defmodule Pleroma.Repo.Migrations.AutolinkerToLinkifyTest do
  use Pleroma.DataCase
  import Pleroma.Factory
  alias Pleroma.ConfigDB

  setup_all do
    [{module, _}] =
      Code.require_file("20200716195806_autolinker_to_linkify.exs", "priv/repo/migrations")

    {:ok, %{migration: module}}
  end

  test "change/0 converts auto_linker opts for Pleroma.Formatter", %{migration: migration} do
    autolinker_opts = [
      extra: true,
      validate_tld: true,
      class: false,
      strip_prefix: false,
      new_window: false,
      rel: "ugc"
    ]

    insert(:config, group: :auto_linker, key: :opts, value: autolinker_opts)

    migration.change()

    assert nil == ConfigDB.get_by_params(%{group: :auto_linker, key: :opts})

    %{value: new_opts} = ConfigDB.get_by_params(%{group: :pleroma, key: Pleroma.Formatter})

    assert new_opts == [
             class: false,
             extra: true,
             new_window: false,
             rel: "ugc",
             strip_prefix: false
           ]

    {text, _mentions, []} =
      Pleroma.Formatter.linkify(
        "https://www.businessinsider.com/walmart-will-close-stores-on-thanksgiving-ending-black-friday-tradition-2020-7\n\nOmg will COVID finally end Black Friday???"
      )

    assert text ==
             "<a href=\"https://www.businessinsider.com/walmart-will-close-stores-on-thanksgiving-ending-black-friday-tradition-2020-7\" rel=\"ugc\">https://www.businessinsider.com/walmart-will-close-stores-on-thanksgiving-ending-black-friday-tradition-2020-7</a>\n\nOmg will COVID finally end Black Friday???"
  end

  test "transform_opts/1 returns a list of compatible opts", %{migration: migration} do
    old_opts = [
      extra: true,
      validate_tld: true,
      class: false,
      strip_prefix: false,
      new_window: false,
      rel: "ugc"
    ]

    expected_opts = [
      class: false,
      extra: true,
      new_window: false,
      rel: "ugc",
      strip_prefix: false
    ]

    assert migration.transform_opts(old_opts) == expected_opts
  end
end
