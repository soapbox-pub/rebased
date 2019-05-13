# Pleroma: A lightweight social networking server
# Copyright © 2017-2018 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Mix.Tasks.Pleroma.Conversations do
  use Mix.Task
  alias Mix.Tasks.Pleroma.Common
  alias Pleroma.Conversation

  @shortdoc "Manages Pleroma conversations."
  @moduledoc """
  Manages Pleroma conversations.

  ## Create a conversation for all existing DMs. Can be safely re-run.

      mix pleroma.conversations bump_all

  """
  def run(["bump_all"]) do
    Common.start_pleroma()
    Conversation.bump_for_all_activities()
  end
end
