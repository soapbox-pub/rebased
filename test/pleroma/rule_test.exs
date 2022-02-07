# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.RuleTest do
  use Pleroma.DataCase, async: true

  alias Pleroma.Repo
  alias Pleroma.Rule

  test "getting a list of rules sorted by priority" do
    %{id: id1} = Rule.create(%{text: "Example rule"})
    %{id: id2} = Rule.create(%{text: "Second rule", priority: 2})
    %{id: id3} = Rule.create(%{text: "Third rule", priority: 1})

    rules =
      Rule.query()
      |> Repo.all()

    assert [%{id: ^id1}, %{id: ^id3}, %{id: ^id2}] = rules
  end

  test "creating rules" do
    %{id: id} = Rule.create(%{text: "Example rule"})

    assert %{text: "Example rule"} = Rule.get(id)
  end

  test "editing rules" do
    %{id: id} = Rule.create(%{text: "Example rule"})

    Rule.update(%{text: "There are no rules", priority: 2}, id)

    assert %{text: "There are no rules", priority: 2} = Rule.get(id)
  end

  test "deleting rules" do
    %{id: id} = Rule.create(%{text: "Example rule"})

    Rule.delete(id)

    assert [] =
             Rule.query()
             |> Pleroma.Repo.all()
  end
end
