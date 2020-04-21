# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ApiSpec.Schemas.AccountCreateRequest do
  alias OpenApiSpex.Schema
  require OpenApiSpex

  OpenApiSpex.schema(%{
    title: "AccountCreateRequest",
    description: "POST body for creating an account",
    type: :object,
    properties: %{
      reason: %Schema{
        type: :string,
        description:
          "Text that will be reviewed by moderators if registrations require manual approval"
      },
      username: %Schema{type: :string, description: "The desired username for the account"},
      email: %Schema{
        type: :string,
        description:
          "The email address to be used for login. Required when `account_activation_required` is enabled.",
        format: :email
      },
      password: %Schema{
        type: :string,
        description: "The password to be used for login",
        format: :password
      },
      agreement: %Schema{
        type: :boolean,
        description:
          "Whether the user agrees to the local rules, terms, and policies. These should be presented to the user in order to allow them to consent before setting this parameter to TRUE."
      },
      locale: %Schema{
        type: :string,
        description: "The language of the confirmation email that will be sent"
      },
      # Pleroma-specific properties:
      fullname: %Schema{type: :string, description: "Full name"},
      bio: %Schema{type: :string, description: "Bio", default: ""},
      captcha_solution: %Schema{type: :string, description: "Provider-specific captcha solution"},
      captcha_token: %Schema{type: :string, description: "Provider-specific captcha token"},
      captcha_answer_data: %Schema{type: :string, description: "Provider-specific captcha data"},
      token: %Schema{
        type: :string,
        description: "Invite token required when the registrations aren't public"
      }
    },
    required: [:username, :password, :agreement],
    example: %{
      "username" => "cofe",
      "email" => "cofe@example.com",
      "password" => "secret",
      "agreement" => "true",
      "bio" => "☕️"
    }
  })
end
