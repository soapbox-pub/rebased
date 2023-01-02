# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.ActivityPub.Streaming do
  @callback stream_out(struct()) :: any()
  @callback stream_out_participations(struct(), struct()) :: any()
end
