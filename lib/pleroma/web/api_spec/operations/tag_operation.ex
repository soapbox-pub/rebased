defmodule Pleroma.Web.ApiSpec.TagOperation do
  alias OpenApiSpex.Operation
  alias OpenApiSpex.Schema
  alias Pleroma.Web.ApiSpec.Schemas.ApiError
  alias Pleroma.Web.ApiSpec.Schemas.Tag

  def open_api_operation(action) do
    operation = String.to_existing_atom("#{action}_operation")
    apply(__MODULE__, operation, [])
  end

  def show_operation do
    %Operation{
      tags: ["Tags"],
      summary: "Hashtag",
      description: "View a hashtag",
      security: [%{"oAuth" => ["read"]}],
      parameters: [id_param()],
      operationId: "TagController.show",
      responses: %{
        200 => Operation.response("Hashtag", "application/json", Tag),
        404 => Operation.response("Not Found", "application/json", ApiError)
      }
    }
  end

  def follow_operation do
    %Operation{
      tags: ["Tags"],
      summary: "Follow a hashtag",
      description: "Follow a hashtag",
      security: [%{"oAuth" => ["write:follows"]}],
      parameters: [id_param()],
      operationId: "TagController.follow",
      responses: %{
        200 => Operation.response("Hashtag", "application/json", Tag),
        404 => Operation.response("Not Found", "application/json", ApiError)
      }
    }
  end

  def unfollow_operation do
    %Operation{
      tags: ["Tags"],
      summary: "Unfollow a hashtag",
      description: "Unfollow a hashtag",
      security: [%{"oAuth" => ["write:follow"]}],
      parameters: [id_param()],
      operationId: "TagController.unfollow",
      responses: %{
        200 => Operation.response("Hashtag", "application/json", Tag),
        404 => Operation.response("Not Found", "application/json", ApiError)
      }
    }
  end

  defp id_param do
    Operation.parameter(
      :id,
      :path,
      %Schema{type: :string},
      "Name of the hashtag"
    )
  end
end
