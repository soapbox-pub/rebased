# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Utils.Colors.RGB do
  defstruct red: 0, green: 0, blue: 0

  @type t :: %__MODULE__{
          red: non_neg_integer(),
          green: non_neg_integer(),
          blue: non_neg_integer()
        }
end
