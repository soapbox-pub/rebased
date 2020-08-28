# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.OTPVersionTest do
  use ExUnit.Case, async: true

  alias Pleroma.OTPVersion

  describe "check/1" do
    test "22.4" do
      assert OTPVersion.get_version_from_files(["test/fixtures/warnings/otp_version/22.4"]) ==
               "22.4"
    end

    test "22.1" do
      assert OTPVersion.get_version_from_files(["test/fixtures/warnings/otp_version/22.1"]) ==
               "22.1"
    end

    test "21.1" do
      assert OTPVersion.get_version_from_files(["test/fixtures/warnings/otp_version/21.1"]) ==
               "21.1"
    end

    test "23.0" do
      assert OTPVersion.get_version_from_files(["test/fixtures/warnings/otp_version/23.0"]) ==
               "23.0"
    end

    test "with non existance file" do
      assert OTPVersion.get_version_from_files([
               "test/fixtures/warnings/otp_version/non-exising",
               "test/fixtures/warnings/otp_version/22.4"
             ]) == "22.4"
    end

    test "empty paths" do
      assert OTPVersion.get_version_from_files([]) == nil
    end
  end
end
