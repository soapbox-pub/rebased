# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ApiSpec.PleromaEventOperation do
  alias OpenApiSpex.Operation
  alias OpenApiSpex.Schema
  alias Pleroma.Web.ApiSpec.AccountOperation
  alias Pleroma.Web.ApiSpec.Schemas.Account
  alias Pleroma.Web.ApiSpec.Schemas.ApiError
  alias Pleroma.Web.ApiSpec.Schemas.FlakeID
  alias Pleroma.Web.ApiSpec.Schemas.ParticipationRequest
  alias Pleroma.Web.ApiSpec.Schemas.Status
  alias Pleroma.Web.ApiSpec.StatusOperation

  import Pleroma.Web.ApiSpec.Helpers

  def open_api_operation(action) do
    operation = String.to_existing_atom("#{action}_operation")
    apply(__MODULE__, operation, [])
  end

  def create_operation do
    %Operation{
      tags: ["Event actions"],
      summary: "Publish new status",
      security: [%{"oAuth" => ["write"]}],
      description: "Create a new event",
      operationId: "PleromaAPI.EventController.create",
      requestBody: request_body("Parameters", create_request(), required: true),
      responses: %{
        200 => event_response(),
        422 => Operation.response("Bad Request", "application/json", ApiError)
      }
    }
  end

  def update_operation do
    %Operation{
      tags: ["Event actions"],
      summary: "Update event",
      description: "Change the content of an event",
      operationId: "PleromaAPI.EventController.update",
      security: [%{"oAuth" => ["write"]}],
      parameters: [id_param()],
      requestBody: request_body("Parameters", update_request(), required: true),
      responses: %{
        200 => event_response(),
        403 => Operation.response("Forbidden", "application/json", ApiError),
        404 => Operation.response("Not Found", "application/json", ApiError)
      }
    }
  end

  def participations_operation do
    %Operation{
      tags: ["Event actions"],
      summary: "Participants list",
      description: "View who joined a given event",
      operationId: "EventController.participations",
      security: [%{"oAuth" => ["read"]}],
      parameters: [id_param()],
      responses: %{
        200 =>
          Operation.response(
            "Array of Accounts",
            "application/json",
            AccountOperation.array_of_accounts()
          ),
        403 => Operation.response("Error", "application/json", ApiError),
        404 => Operation.response("Not Found", "application/json", ApiError)
      }
    }
  end

  def participation_requests_operation do
    %Operation{
      tags: ["Event actions"],
      summary: "Participation requests list",
      description: "View who wants to join the event",
      operationId: "EventController.participations",
      security: [%{"oAuth" => ["read"]}],
      parameters: [id_param()],
      responses: %{
        200 =>
          Operation.response(
            "Array of participation requests",
            "application/json",
            array_of_participation_requests()
          ),
        403 => Operation.response("Forbidden", "application/json", ApiError),
        404 => Operation.response("Not Found", "application/json", ApiError)
      }
    }
  end

  def join_operation do
    %Operation{
      tags: ["Event actions"],
      summary: "Participate",
      security: [%{"oAuth" => ["write"]}],
      description: "Participate in an event",
      operationId: "PleromaAPI.EventController.join",
      parameters: [id_param()],
      requestBody:
        request_body(
          "Parameters",
          %Schema{
            type: :object,
            properties: %{
              account: Account,
              participation_message: %Schema{
                type: :string,
                description: "Why the user wants to participate"
              }
            }
          },
          required: false
        ),
      responses: %{
        200 => event_response(),
        400 => Operation.response("Error", "application/json", ApiError),
        404 => Operation.response("Not Found", "application/json", ApiError)
      }
    }
  end

  def leave_operation do
    %Operation{
      tags: ["Event actions"],
      summary: "Unparticipate",
      security: [%{"oAuth" => ["write"]}],
      description: "Delete event participation",
      operationId: "PleromaAPI.EventController.leave",
      parameters: [id_param()],
      responses: %{
        200 => event_response(),
        400 => Operation.response("Error", "application/json", ApiError),
        404 => Operation.response("Not Found", "application/json", ApiError)
      }
    }
  end

  def authorize_participation_request_operation do
    %Operation{
      tags: ["Event actions"],
      summary: "Accept participation",
      security: [%{"oAuth" => ["write"]}],
      description: "Accept event participation request",
      operationId: "PleromaAPI.EventController.authorize_participation_request",
      parameters: [id_param(), participant_id_param()],
      responses: %{
        200 => event_response(),
        403 => Operation.response("Forbidden", "application/json", ApiError),
        404 => Operation.response("Not Found", "application/json", ApiError)
      }
    }
  end

  def reject_participation_request_operation do
    %Operation{
      tags: ["Event actions"],
      summary: "Reject participation",
      security: [%{"oAuth" => ["write"]}],
      description: "Reject event participation request",
      operationId: "PleromaAPI.EventController.reject_participation_request",
      parameters: [id_param(), participant_id_param()],
      responses: %{
        200 => event_response(),
        403 => Operation.response("Forbidden", "application/json", ApiError),
        404 => Operation.response("Not Found", "application/json", ApiError)
      }
    }
  end

  def export_ics_operation do
    %Operation{
      tags: ["Event actions"],
      summary: "Export status",
      description: "Export event to .ics",
      operationId: "PleromaAPI.EventController.export_ics",
      security: [%{"oAuth" => ["read:statuses"]}],
      parameters: [id_param()],
      responses: %{
        200 =>
          Operation.response("Event", "text/calendar; charset=utf-8", %Schema{type: :string}),
        404 => Operation.response("Not Found", "application/json", ApiError)
      }
    }
  end

  def joined_events_operation do
    %Operation{
      tags: ["Event actions"],
      summary: "Joined events",
      description: "Get your joined events",
      operationId: "PleromaAPI.EventController.joined_events",
      security: [%{"oAuth" => ["read:statuses"]}],
      parameters: [
        Operation.parameter(
          :state,
          :query,
          %Schema{type: :string, enum: ["pending", "reject", "accept"]},
          "Filter by join state"
        )
        | pagination_params()
      ],
      responses: %{
        200 =>
          Operation.response(
            "Array of Statuses",
            "application/json",
            StatusOperation.array_of_statuses()
          )
      }
    }
  end

  defp create_request do
    %Schema{
      title: "EventCreateRequest",
      type: :object,
      properties: %{
        name: %Schema{
          type: :string,
          description: "Name of the event."
        },
        status: %Schema{
          type: :string,
          nullable: true,
          description: "Text description of the event."
        },
        banner_id: %Schema{
          nullable: true,
          type: :string,
          description: "Attachment id to be attached as banner."
        },
        start_time: %Schema{
          type: :string,
          format: :"date-time",
          description: "Start time."
        },
        end_time: %Schema{
          type: :string,
          format: :"date-time",
          description: "End time."
        },
        join_mode: %Schema{
          type: :string,
          enum: ["free", "restricted"]
        },
        location_id: %Schema{
          type: :string,
          description: "Location ID from geospatial provider",
          nullable: true
        },
        language: %Schema{
          type: :string,
          nullable: true,
          description: "ISO 639 language code for this status."
        }
      },
      example: %{
        "name" => "Example event",
        "status" => "No information for now.",
        "start_time" => "2022-02-21T22:00:00.000Z",
        "end_time" => "2022-02-21T23:00:00.000Z"
      }
    }
  end

  defp update_request do
    %Schema{
      title: "EventUpdateRequest",
      type: :object,
      properties: %{
        name: %Schema{
          type: :string,
          description: "Name of the event."
        },
        status: %Schema{
          type: :string,
          nullable: true,
          description: "Text description of the event."
        },
        banner_id: %Schema{
          nullable: true,
          type: :string,
          description: "Attachment id to be attached as banner."
        },
        start_time: %Schema{
          type: :string,
          format: :"date-time",
          description: "Start time."
        },
        end_time: %Schema{
          type: :string,
          format: :"date-time",
          description: "End time."
        },
        location_id: %Schema{
          type: :string,
          description: "Location ID from geospatial provider",
          nullable: true
        }
      },
      example: %{
        "name" => "Updated event",
        "status" => "We had to reschedule the event.",
        "start_time" => "2022-02-22T22:00:00.000Z",
        "end_time" => "2022-02-22T23:00:00.000Z"
      }
    }
  end

  defp event_response do
    Operation.response(
      "Status",
      "application/json",
      Status
    )
  end

  defp id_param do
    Operation.parameter(:id, :path, FlakeID, "Event ID",
      example: "9umDrYheeY451cQnEe",
      required: true
    )
  end

  defp participant_id_param do
    Operation.parameter(:participant_id, :path, FlakeID, "Event participant ID",
      example: "9umDrYheeY451cQnEe",
      required: true
    )
  end

  def array_of_participation_requests do
    %Schema{
      title: "ArrayOfParticipationRequests",
      type: :array,
      items: ParticipationRequest,
      example: [ParticipationRequest.schema().example]
    }
  end
end
