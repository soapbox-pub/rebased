# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.ExecTest do
  alias Pleroma.Exec

  use Pleroma.DataCase

  test "it starts" do
    assert {:ok, _} = Exec.ensure_started()
  end
end
