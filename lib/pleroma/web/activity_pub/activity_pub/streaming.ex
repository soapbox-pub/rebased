# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.ActivityPub.Streaming do
  alias Pleroma.Activity
  alias Pleroma.Object
  alias Pleroma.User

  @callback stream_out(Activity.t()) :: any()
  @callback stream_out_participations(Object.t(), User.t()) :: any()
end
