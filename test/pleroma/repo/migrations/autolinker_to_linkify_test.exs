# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.AutolinkerToLinkifyTest do
  use Pleroma.DataCase
  import Pleroma.Factory
  import Pleroma.Tests.Helpers
  alias Pleroma.ConfigDB

  setup do: clear_config(Pleroma.Formatter)
  setup_all do: require_migration("20200716195806_autolinker_to_linkify")

  test "change/0 converts auto_linker opts for Pleroma.Formatter", %{migration: migration} do
    autolinker_opts = [
      extra: true,
      validate_tld: true,
      class: false,
      strip_prefix: false,
      new_window: false,
      rel: "testing"
    ]

    insert(:config, group: :auto_linker, key: :opts, value: autolinker_opts)

    migration.change()

    assert nil == ConfigDB.get_by_params(%{group: :auto_linker, key: :opts})

    %{value: new_opts} = ConfigDB.get_by_params(%{group: :pleroma, key: Pleroma.Formatter})

    assert new_opts == [
             class: false,
             extra: true,
             new_window: false,
             rel: "testing",
             strip_prefix: false
           ]

    clear_config(Pleroma.Formatter, new_opts)
    assert new_opts == Pleroma.Config.get(Pleroma.Formatter)

    {text, _mentions, []} =
      Pleroma.Formatter.linkify(
        "https://www.businessinsider.com/walmart-will-close-stores-on-thanksgiving-ending-black-friday-tradition-2020-7\n\nOmg will COVID finally end Black Friday???"
      )

    assert text ==
             "<a href=\"https://www.businessinsider.com/walmart-will-close-stores-on-thanksgiving-ending-black-friday-tradition-2020-7\" rel=\"testing\">https://www.businessinsider.com/walmart-will-close-stores-on-thanksgiving-ending-black-friday-tradition-2020-7</a>\n\nOmg will COVID finally end Black Friday???"
  end

  test "transform_opts/1 returns a list of compatible opts", %{migration: migration} do
    old_opts = [
      extra: true,
      validate_tld: true,
      class: false,
      strip_prefix: false,
      new_window: false,
      rel: "qqq"
    ]

    expected_opts = [
      class: false,
      extra: true,
      new_window: false,
      rel: "qqq",
      strip_prefix: false
    ]

    assert migration.transform_opts(old_opts) == expected_opts
  end
end
