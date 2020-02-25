# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.CaptchaTest do
  use Pleroma.DataCase

  import Tesla.Mock

  alias Pleroma.Captcha
  alias Pleroma.Captcha.Kocaptcha
  alias Pleroma.Captcha.Native

  @ets_options [:ordered_set, :private, :named_table, {:read_concurrency, true}]

  clear_config([Pleroma.Captcha, :enabled])

  describe "Kocaptcha" do
    setup do
      ets_name = Kocaptcha.Ets
      ^ets_name = :ets.new(ets_name, @ets_options)

      mock(fn
        %{method: :get, url: "https://captcha.kotobank.ch/new"} ->
          json(%{
            md5: "63615261b77f5354fb8c4e4986477555",
            token: "afa1815e14e29355e6c8f6b143a39fa2",
            url: "/captchas/afa1815e14e29355e6c8f6b143a39fa2.png"
          })
      end)

      :ok
    end

    test "new and validate" do
      new = Kocaptcha.new()

      token = "afa1815e14e29355e6c8f6b143a39fa2"
      url = "https://captcha.kotobank.ch/captchas/afa1815e14e29355e6c8f6b143a39fa2.png"

      assert %{
               answer_data: answer,
               token: ^token,
               url: ^url,
               type: :kocaptcha
             } = new

      assert Kocaptcha.validate(token, "7oEy8c", answer) == :ok
    end
  end

  describe "Native" do
    test "new and validate" do
      new = Native.new()

      assert %{
               answer_data: answer,
               token: token,
               type: :native,
               url: "data:image/png;base64," <> _
             } = new

      assert is_binary(answer)
      assert :ok = Native.validate(token, answer, answer)
      assert {:error, "Invalid CAPTCHA"} == Native.validate(token, answer, answer <> "foobar")
    end
  end

  describe "Captcha Wrapper" do
    test "validate" do
      Pleroma.Config.put([Pleroma.Captcha, :enabled], true)

      new = Captcha.new()

      assert %{
               answer_data: answer,
               token: token
             } = new

      assert is_binary(answer)
      assert :ok = Captcha.validate(token, "63615261b77f5354fb8c4e4986477555", answer)
    end

    test "doesn't validate invalid answer" do
      Pleroma.Config.put([Pleroma.Captcha, :enabled], true)

      new = Captcha.new()

      assert %{
               answer_data: answer,
               token: token
             } = new

      assert is_binary(answer)

      assert {:error, "Invalid answer data"} =
               Captcha.validate(token, "63615261b77f5354fb8c4e4986477555", answer <> "foobar")
    end

    test "nil answer_data" do
      Pleroma.Config.put([Pleroma.Captcha, :enabled], true)

      new = Captcha.new()

      assert %{
               answer_data: answer,
               token: token
             } = new

      assert is_binary(answer)

      assert {:error, "Invalid answer data"} =
               Captcha.validate(token, "63615261b77f5354fb8c4e4986477555", nil)
    end
  end
end
