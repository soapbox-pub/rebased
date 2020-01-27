# Pleroma: A lightweight social networking server
# Copyright © 2017-2018 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.RuntimeTest do
  use ExUnit.Case, async: true

  test "it loads custom runtime modules" do
    assert Code.ensure_compiled?(RuntimeModule)
  end
end
