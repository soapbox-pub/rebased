# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.OTPVersionTest do
  use ExUnit.Case, async: true

  alias Pleroma.OTPVersion

  describe "check/1" do
    test "22.4" do
      assert OTPVersion.check(["test/fixtures/warnings/otp_version/22.4"]) == :ok
    end

    test "22.1" do
      assert OTPVersion.check(["test/fixtures/warnings/otp_version/22.1"]) == {:error, "22.1"}
    end

    test "21.1" do
      assert OTPVersion.check(["test/fixtures/warnings/otp_version/21.1"]) == {:error, "21.1"}
    end

    test "23.0" do
      assert OTPVersion.check(["test/fixtures/warnings/otp_version/23.0"]) == :ok
    end

    test "with non existance file" do
      assert OTPVersion.check([
               "test/fixtures/warnings/otp_version/non-exising",
               "test/fixtures/warnings/otp_version/22.4"
             ]) == :ok
    end

    test "empty paths" do
      assert OTPVersion.check([]) == :undefined
    end
  end
end
