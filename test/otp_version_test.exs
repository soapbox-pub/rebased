defmodule Pleroma.OTPVersionTest do
  use ExUnit.Case, async: true

  alias Pleroma.OTPVersion

  describe "get_and_check_version/2" do
    test "22.4" do
      assert OTPVersion.get_and_check_version(Tesla.Adapter.Gun, [
               "test/fixtures/warnings/otp_version/22.4"
             ]) == :ok
    end

    test "22.1" do
      assert OTPVersion.get_and_check_version(Tesla.Adapter.Gun, [
               "test/fixtures/warnings/otp_version/22.1"
             ]) == {:error, "22.1"}
    end

    test "21.1" do
      assert OTPVersion.get_and_check_version(Tesla.Adapter.Gun, [
               "test/fixtures/warnings/otp_version/21.1"
             ]) == {:error, "21.1"}
    end

    test "23.0" do
      assert OTPVersion.get_and_check_version(Tesla.Adapter.Gun, [
               "test/fixtures/warnings/otp_version/23.0"
             ]) == :ok
    end

    test "undefined" do
      assert OTPVersion.get_and_check_version(Tesla.Adapter.Gun, [
               "test/fixtures/warnings/otp_version/undefined"
             ]) == :undefined
    end

    test "not parsable" do
      assert OTPVersion.get_and_check_version(Tesla.Adapter.Gun, [
               "test/fixtures/warnings/otp_version/error"
             ]) == :undefined
    end

    test "with non existance file" do
      assert OTPVersion.get_and_check_version(Tesla.Adapter.Gun, [
               "test/fixtures/warnings/otp_version/non-exising",
               "test/fixtures/warnings/otp_version/22.4"
             ]) == :ok
    end

    test "empty paths" do
      assert OTPVersion.get_and_check_version(Tesla.Adapter.Gun, []) == :undefined
    end

    test "another adapter" do
      assert OTPVersion.get_and_check_version(Tesla.Adapter.Hackney, []) == :ok
    end
  end
end
