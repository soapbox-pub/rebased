# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.ObjectValidator.Validating do
  @callback validate(map(), keyword()) :: {:ok, map(), keyword()} | {:error, any()}
end
