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
      security: [%{"oAuth" => ["write:follows"]}],
      parameters: [id_param()],
      operationId: "TagController.unfollow",
      responses: %{
        200 => Operation.response("Hashtag", "application/json", Tag),
        404 => Operation.response("Not Found", "application/json", ApiError)
      }
    }
  end

  def show_followed_operation do
    %Operation{
      tags: ["Tags"],
      summary: "Followed hashtags",
      description: "View a list of hashtags the currently authenticated user is following",
      parameters: pagination_params(),
      security: [%{"oAuth" => ["read:follows"]}],
      operationId: "TagController.show_followed",
      responses: %{
        200 =>
          Operation.response("Hashtags", "application/json", %Schema{
            type: :array,
            items: Tag
          }),
        403 => Operation.response("Forbidden", "application/json", ApiError),
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

  def pagination_params do
    [
      Operation.parameter(:max_id, :query, :integer, "Return items older than this ID"),
      Operation.parameter(
        :min_id,
        :query,
        :integer,
        "Return the oldest items newer than this ID"
      ),
      Operation.parameter(
        :limit,
        :query,
        %Schema{type: :integer, default: 20},
        "Maximum number of items to return. Will be ignored if it's more than 40"
      )
    ]
  end
end
