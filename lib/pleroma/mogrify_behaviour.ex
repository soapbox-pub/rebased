# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.MogrifyBehaviour do
  @moduledoc """
  Behaviour for Mogrify operations.
  This module defines the interface for Mogrify operations that can be mocked in tests.
  """

  @callback open(binary()) :: map()
  @callback custom(map(), binary()) :: map()
  @callback custom(map(), binary(), binary()) :: map()
  @callback save(map(), keyword()) :: map()
end
