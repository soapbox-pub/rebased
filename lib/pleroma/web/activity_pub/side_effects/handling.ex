# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.SideEffects.Handling do
  @callback handle(map(), keyword()) :: {:ok, map(), keyword()} | {:error, any()}
  @callback handle_after_transaction(map()) :: map()
end
