defmodule Pleroma.CaptchaTest do
  use ExUnit.Case

  import Tesla.Mock

  @ets_options [:ordered_set, :private, :named_table, {:read_concurrency, true}]

  describe "Kocaptcha" do
    setup do
      ets_name = Pleroma.Captcha.Kocaptcha.Ets
      ^ets_name = :ets.new(ets_name, @ets_options)

      mock(fn
        %{method: :get, url: "http://localhost:9093/new"} ->
          json(%{
            md5: "63615261b77f5354fb8c4e4986477555",
            token: "afa1815e14e29355e6c8f6b143a39fa2",
            url: "/captchas/afa1815e14e29355e6c8f6b143a39fa2.png"
          })
      end)

      :ok
    end

    test "new and validate" do
      assert Pleroma.Captcha.Kocaptcha.new() == %{
               type: :kocaptcha,
               token: "afa1815e14e29355e6c8f6b143a39fa2",
               url: "http://localhost:9093/captchas/afa1815e14e29355e6c8f6b143a39fa2.png"
             }

      assert Pleroma.Captcha.Kocaptcha.validate(
               "afa1815e14e29355e6c8f6b143a39fa2",
               "7oEy8c"
             )
    end
  end
end
