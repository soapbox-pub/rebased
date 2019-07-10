# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Mix.PleromaTest do
  use ExUnit.Case, async: true
  import Mix.Pleroma

  setup_all do
    Mix.shell(Mix.Shell.Process)

    on_exit(fn ->
      Mix.shell(Mix.Shell.IO)
    end)

    :ok
  end

  describe "shell_prompt/1" do
    test "input" do
      send(self(), {:mix_shell_input, :prompt, "Yes"})

      answer = shell_prompt("Do you want this?")
      assert_received {:mix_shell, :prompt, [message]}
      assert message =~ "Do you want this?"
      assert answer == "Yes"
    end

    test "with defval" do
      send(self(), {:mix_shell_input, :prompt, "\n"})

      answer = shell_prompt("Do you want this?", "defval")

      assert_received {:mix_shell, :prompt, [message]}
      assert message =~ "Do you want this? [defval]"
      assert answer == "defval"
    end
  end

  describe "get_option/3" do
    test "get from options" do
      assert get_option([domain: "some-domain.com"], :domain, "Promt") == "some-domain.com"
    end

    test "get from prompt" do
      send(self(), {:mix_shell_input, :prompt, "another-domain.com"})
      assert get_option([], :domain, "Prompt") == "another-domain.com"
    end
  end
end
