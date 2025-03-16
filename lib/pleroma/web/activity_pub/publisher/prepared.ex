# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.Publisher.Prepared do
  @type t :: %__MODULE__{}
  defstruct [:activity_id, :json, :date, :signature, :digest, :inbox, :unreachable_since]
end
