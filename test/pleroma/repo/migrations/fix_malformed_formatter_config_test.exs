# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.FixMalformedFormatterConfigTest do
  use Pleroma.DataCase
  import Pleroma.Factory
  import Pleroma.Tests.Helpers
  alias Pleroma.ConfigDB

  setup do: clear_config(Pleroma.Formatter)
  setup_all do: require_migration("20200722185515_fix_malformed_formatter_config")

  test "change/0 converts a map into a list", %{migration: migration} do
    incorrect_opts = %{
      class: false,
      extra: true,
      new_window: false,
      rel: "F",
      strip_prefix: false
    }

    insert(:config, group: :pleroma, key: Pleroma.Formatter, value: incorrect_opts)

    assert :ok == migration.change()

    %{value: new_opts} = ConfigDB.get_by_params(%{group: :pleroma, key: Pleroma.Formatter})

    assert new_opts == [
             class: false,
             extra: true,
             new_window: false,
             rel: "F",
             strip_prefix: false
           ]

    clear_config(Pleroma.Formatter, new_opts)
    assert new_opts == Pleroma.Config.get(Pleroma.Formatter)

    {text, _mentions, []} =
      Pleroma.Formatter.linkify(
        "https://www.businessinsider.com/walmart-will-close-stores-on-thanksgiving-ending-black-friday-tradition-2020-7\n\nOmg will COVID finally end Black Friday???"
      )

    assert text ==
             "<a href=\"https://www.businessinsider.com/walmart-will-close-stores-on-thanksgiving-ending-black-friday-tradition-2020-7\" rel=\"F\">https://www.businessinsider.com/walmart-will-close-stores-on-thanksgiving-ending-black-friday-tradition-2020-7</a>\n\nOmg will COVID finally end Black Friday???"
  end

  test "change/0 skips if Pleroma.Formatter config is already a list", %{migration: migration} do
    opts = [
      class: false,
      extra: true,
      new_window: false,
      rel: "ugc",
      strip_prefix: false
    ]

    insert(:config, group: :pleroma, key: Pleroma.Formatter, value: opts)

    assert :skipped == migration.change()

    %{value: new_opts} = ConfigDB.get_by_params(%{group: :pleroma, key: Pleroma.Formatter})

    assert new_opts == opts
  end

  test "change/0 skips if Pleroma.Formatter is empty", %{migration: migration} do
    assert :skipped == migration.change()
  end
end
