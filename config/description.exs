import Config

websocket_config = [
  path: "/websocket",
  serializer: [
    {Phoenix.Socket.V1.JSONSerializer, "~> 1.0.0"},
    {Phoenix.Socket.V2.JSONSerializer, "~> 2.0.0"}
  ],
  timeout: 60_000,
  transport_log: false,
  compress: false
]

installed_frontend_options = [
  %{
    key: "name",
    label: "Name",
    type: :string,
    description:
      "Name of the installed frontend. Valid config must include both `Name` and `Reference` values."
  },
  %{
    key: "ref",
    label: "Reference",
    type: :string,
    description:
      "Reference of the installed frontend to be used. Valid config must include both `Name` and `Reference` values."
  }
]

frontend_options = [
  %{
    key: "name",
    label: "Name",
    type: :string,
    description: "Name of the frontend."
  },
  %{
    key: "ref",
    label: "Reference",
    type: :string,
    description: "Reference of the frontend to be used."
  },
  %{
    key: "git",
    label: "Git Repository URL",
    type: :string,
    description: "URL of the git repository of the frontend"
  },
  %{
    key: "build_url",
    label: "Build URL",
    type: :string,
    description:
      "Either an url to a zip file containing the frontend or a template to build it by inserting the `ref`. The string `${ref}` will be replaced by the configured `ref`.",
    example: "https://some.url/builds/${ref}.zip"
  },
  %{
    key: "build_dir",
    label: "Build directory",
    type: :string,
    description: "The directory inside the zip file "
  },
  %{
    key: "custom-http-headers",
    label: "Custom HTTP headers",
    type: {:list, :string},
    description: "The custom HTTP headers for the frontend"
  }
]

config :pleroma, :config_description, [
  %{
    group: :pleroma,
    key: Pleroma.Upload,
    type: :group,
    description: "Upload general settings",
    children: [
      %{
        key: :uploader,
        type: :module,
        description: "Module which will be used for uploads",
        suggestions: {:list_behaviour_implementations, Pleroma.Uploaders.Uploader}
      },
      %{
        key: :filters,
        type: {:list, :module},
        description:
          "List of filter modules for uploads. Module names are shortened (removed leading `Pleroma.Upload.Filter.` part), but on adding custom module you need to use full name.",
        suggestions: {:list_behaviour_implementations, Pleroma.Upload.Filter}
      },
      %{
        key: :link_name,
        type: :boolean,
        description:
          "If enabled, a name parameter will be added to the URL of the upload. For example `https://instance.tld/media/imagehash.png?name=realname.png`."
      },
      %{
        key: :base_url,
        label: "Base URL",
        type: :string,
        description:
          "Base URL for the uploads. Required if you use a CDN or host attachments under a different domain.",
        suggestions: [
          "https://cdn-host.com"
        ]
      },
      %{
        key: :proxy_remote,
        type: :boolean,
        description: """
        Proxy requests to the remote uploader.\n
        Useful if media upload endpoint is not internet accessible.
        """
      },
      %{
        key: :filename_display_max_length,
        type: :integer,
        description: "Set max length of a filename to display. 0 = no limit. Default: 30"
      }
    ]
  },
  %{
    group: :pleroma,
    key: Pleroma.Uploaders.Local,
    type: :group,
    description: "Local uploader-related settings",
    children: [
      %{
        key: :uploads,
        type: :string,
        description: "Path where user's uploads will be saved",
        suggestions: [
          "uploads"
        ]
      }
    ]
  },
  %{
    group: :pleroma,
    key: Pleroma.Uploaders.S3,
    type: :group,
    description: "S3 uploader-related settings",
    children: [
      %{
        key: :bucket,
        type: :string,
        description: "S3 bucket",
        suggestions: [
          "bucket"
        ]
      },
      %{
        key: :bucket_namespace,
        type: :string,
        description: "S3 bucket namespace",
        suggestions: ["pleroma"]
      },
      %{
        key: :truncated_namespace,
        type: :string,
        description:
          "If you use S3 compatible service such as Digital Ocean Spaces or CDN, set folder name or \"\" etc." <>
            " For example, when using CDN to S3 virtual host format, set \"\". At this time, write CNAME to CDN in Upload base_url."
      },
      %{
        key: :streaming_enabled,
        type: :boolean,
        description:
          "Enable streaming uploads, when enabled the file will be sent to the server in chunks as it's being read. This may be unsupported by some providers, try disabling this if you have upload problems."
      }
    ]
  },
  %{
    group: :pleroma,
    key: Pleroma.Upload.Filter.Mogrify,
    type: :group,
    description: "Uploads mogrify filter settings",
    children: [
      %{
        key: :args,
        type: [:string, {:list, :string}, {:list, :tuple}],
        description:
          "List of actions for the mogrify command. It's possible to add self-written settings as string. " <>
            "For example `auto-orient, strip, {\"resize\", \"3840x1080>\"}` value will be parsed into valid list of the settings.",
        suggestions: [
          "strip",
          "auto-orient",
          {"implode", "1"}
        ]
      }
    ]
  },
  %{
    group: :pleroma,
    key: Pleroma.Upload.Filter.AnonymizeFilename,
    type: :group,
    description: "Filter replaces the filename of the upload",
    children: [
      %{
        key: :text,
        type: :string,
        description:
          "Text to replace filenames in links. If no setting, {random}.extension will be used. You can get the original" <>
            " filename extension by using {extension}, for example custom-file-name.{extension}.",
        suggestions: [
          "custom-file-name.{extension}"
        ]
      }
    ]
  },
  %{
    group: :pleroma,
    key: Pleroma.Emails.Mailer,
    type: :group,
    description: "Mailer-related settings",
    children: [
      %{
        key: :enabled,
        label: "Mailer Enabled",
        type: :boolean
      },
      %{
        key: :adapter,
        type: :module,
        description:
          "One of the mail adapters listed in [Swoosh documentation](https://hexdocs.pm/swoosh/Swoosh.html#module-adapters)",
        suggestions: [
          Swoosh.Adapters.AmazonSES,
          Swoosh.Adapters.Dyn,
          Swoosh.Adapters.Gmail,
          Swoosh.Adapters.Mailgun,
          Swoosh.Adapters.Mailjet,
          Swoosh.Adapters.Mandrill,
          Swoosh.Adapters.Postmark,
          Swoosh.Adapters.SMTP,
          Swoosh.Adapters.Sendgrid,
          Swoosh.Adapters.Sendmail,
          Swoosh.Adapters.SocketLabs,
          Swoosh.Adapters.SparkPost
        ]
      },
      %{
        group: {:subgroup, Swoosh.Adapters.SMTP},
        key: :relay,
        type: :string,
        description: "Hostname or IP address",
        suggestions: ["smtp.example.com"]
      },
      %{
        group: {:subgroup, Swoosh.Adapters.SMTP},
        key: :port,
        type: :integer,
        description: "SMTP port",
        suggestions: ["1025"]
      },
      %{
        group: {:subgroup, Swoosh.Adapters.SMTP},
        key: :username,
        type: :string,
        description: "SMTP AUTH username",
        suggestions: ["user@example.com"]
      },
      %{
        group: {:subgroup, Swoosh.Adapters.SMTP},
        key: :password,
        type: :string,
        description: "SMTP AUTH password",
        suggestions: ["password"]
      },
      %{
        group: {:subgroup, Swoosh.Adapters.SMTP},
        key: :ssl,
        label: "Use SSL",
        type: :boolean,
        description: "Use Implicit SSL/TLS. e.g. port 465"
      },
      %{
        group: {:subgroup, Swoosh.Adapters.SMTP},
        key: :tls,
        label: "STARTTLS Mode",
        type: {:dropdown, :atom},
        description: "Explicit TLS (STARTTLS) enforcement mode",
        suggestions: [:if_available, :always, :never]
      },
      %{
        group: {:subgroup, Swoosh.Adapters.SMTP},
        key: :auth,
        label: "AUTH Mode",
        type: {:dropdown, :atom},
        description: "SMTP AUTH enforcement mode",
        suggestions: [:if_available, :always, :never]
      },
      %{
        group: {:subgroup, Swoosh.Adapters.SMTP},
        key: :retries,
        type: :integer,
        description: "SMTP temporary (4xx) error retries",
        suggestions: [1]
      },
      %{
        group: {:subgroup, Swoosh.Adapters.Sendgrid},
        key: :api_key,
        label: "SendGrid API Key",
        type: :string,
        suggestions: ["YOUR_API_KEY"]
      },
      %{
        group: {:subgroup, Swoosh.Adapters.Sendmail},
        key: :cmd_path,
        type: :string,
        suggestions: ["/usr/bin/sendmail"]
      },
      %{
        group: {:subgroup, Swoosh.Adapters.Sendmail},
        key: :cmd_args,
        type: :string,
        suggestions: ["-N delay,failure,success"]
      },
      %{
        group: {:subgroup, Swoosh.Adapters.Sendmail},
        key: :qmail,
        label: "Qmail compat mode",
        type: :boolean
      },
      %{
        group: {:subgroup, Swoosh.Adapters.Mandrill},
        key: :api_key,
        label: "Mandrill API Key",
        type: :string,
        suggestions: ["YOUR_API_KEY"]
      },
      %{
        group: {:subgroup, Swoosh.Adapters.Mailgun},
        key: :api_key,
        label: "Mailgun API Key",
        type: :string,
        suggestions: ["YOUR_API_KEY"]
      },
      %{
        group: {:subgroup, Swoosh.Adapters.Mailgun},
        key: :domain,
        type: :string,
        suggestions: ["YOUR_DOMAIN_NAME"]
      },
      %{
        group: {:subgroup, Swoosh.Adapters.Mailjet},
        key: :api_key,
        label: "MailJet Public API Key",
        type: :string,
        suggestions: ["MJ_APIKEY_PUBLIC"]
      },
      %{
        group: {:subgroup, Swoosh.Adapters.Mailjet},
        key: :secret,
        label: "MailJet Private API Key",
        type: :string,
        suggestions: ["MJ_APIKEY_PRIVATE"]
      },
      %{
        group: {:subgroup, Swoosh.Adapters.Postmark},
        key: :api_key,
        label: "Postmark API Key",
        type: :string,
        suggestions: ["X-Postmark-Server-Token"]
      },
      %{
        group: {:subgroup, Swoosh.Adapters.SparkPost},
        key: :api_key,
        label: "SparkPost API key",
        type: :string,
        suggestions: ["YOUR_API_KEY"]
      },
      %{
        group: {:subgroup, Swoosh.Adapters.SparkPost},
        key: :endpoint,
        type: :string,
        suggestions: ["https://api.sparkpost.com/api/v1"]
      },
      %{
        group: {:subgroup, Swoosh.Adapters.AmazonSES},
        key: :access_key,
        label: "AWS Access Key",
        type: :string,
        suggestions: ["AWS_ACCESS_KEY"]
      },
      %{
        group: {:subgroup, Swoosh.Adapters.AmazonSES},
        key: :secret,
        label: "AWS Secret Key",
        type: :string,
        suggestions: ["AWS_SECRET_KEY"]
      },
      %{
        group: {:subgroup, Swoosh.Adapters.AmazonSES},
        key: :region,
        label: "AWS Region",
        type: :string,
        suggestions: ["us-east-1", "us-east-2"]
      },
      %{
        group: {:subgroup, Swoosh.Adapters.Dyn},
        key: :api_key,
        label: "Dyn API Key",
        type: :string,
        suggestions: ["apikey"]
      },
      %{
        group: {:subgroup, Swoosh.Adapters.SocketLabs},
        key: :api_key,
        label: "SocketLabs API Key",
        type: :string,
        suggestions: ["INJECTION_API_KEY"]
      },
      %{
        group: {:subgroup, Swoosh.Adapters.SocketLabs},
        key: :server_id,
        label: "Server ID",
        type: :string,
        suggestions: ["SERVER_ID"]
      },
      %{
        group: {:subgroup, Swoosh.Adapters.Gmail},
        key: :access_token,
        label: "GMail API Access Token",
        type: :string,
        suggestions: ["GMAIL_API_ACCESS_TOKEN"]
      }
    ]
  },
  %{
    group: :pleroma,
    key: :uri_schemes,
    label: "URI Schemes",
    type: :group,
    description: "URI schemes related settings",
    children: [
      %{
        key: :valid_schemes,
        type: {:list, :string},
        description: "List of the scheme part that is considered valid to be an URL",
        suggestions: [
          "https",
          "http",
          "dat",
          "dweb",
          "gopher",
          "hyper",
          "ipfs",
          "ipns",
          "irc",
          "ircs",
          "magnet",
          "mailto",
          "mumble",
          "ssb",
          "xmpp"
        ]
      }
    ]
  },
  %{
    group: :pleroma,
    key: :features,
    type: :group,
    description: "Customizable features",
    children: [
      %{
        key: :improved_hashtag_timeline,
        type: {:dropdown, :atom},
        description:
          "Setting to force toggle / force disable improved hashtags timeline. `:enabled` forces hashtags to be fetched from `hashtags` table for hashtags timeline. `:disabled` forces object-embedded hashtags to be used (slower). Keep it `:auto` for automatic behaviour (it is auto-set to `:enabled` [unless overridden] when HashtagsTableMigrator completes).",
        suggestions: [:auto, :enabled, :disabled]
      }
    ]
  },
  %{
    group: :pleroma,
    key: :populate_hashtags_table,
    type: :group,
    description: "`populate_hashtags_table` background migration settings",
    children: [
      %{
        key: :fault_rate_allowance,
        type: :float,
        description:
          "Max accepted rate of objects that failed in the migration. Any value from 0.0 which tolerates no errors to 1.0 which will enable the feature even if hashtags transfer failed for all records.",
        suggestions: [0.01]
      },
      %{
        key: :sleep_interval_ms,
        type: :integer,
        description:
          "Sleep interval between each chunk of processed records in order to decrease the load on the system (defaults to 0 and should be keep default on most instances)."
      }
    ]
  },
  %{
    group: :pleroma,
    key: :instance,
    type: :group,
    description: "Instance-related settings",
    children: [
      %{
        key: :name,
        type: :string,
        description: "Name of the instance",
        suggestions: [
          "Pleroma"
        ]
      },
      %{
        key: :email,
        label: "Admin Email Address",
        type: :string,
        description: "Email used to reach an Administrator/Moderator of the instance",
        suggestions: [
          "email@example.com"
        ]
      },
      %{
        key: :notify_email,
        label: "Sender Email Address",
        type: :string,
        description: "Envelope FROM address for mail sent via Pleroma",
        suggestions: [
          "notify@example.com"
        ]
      },
      %{
        key: :description,
        type: :string,
        description:
          "The instance's description. It can be seen in nodeinfo and `/api/v1/instance`",
        suggestions: [
          "Very cool instance"
        ]
      },
      %{
        key: :short_description,
        type: :string,
        description:
          "Shorter version of instance description. It can be seen on `/api/v1/instance`",
        suggestions: [
          "Cool instance"
        ]
      },
      %{
        key: :limit,
        type: :integer,
        description: "Posts character limit (CW/Subject included in the counter)",
        suggestions: [
          5_000
        ]
      },
      %{
        key: :remote_limit,
        type: :integer,
        description: "Hard character limit beyond which remote posts will be dropped",
        suggestions: [
          100_000
        ]
      },
      %{
        key: :max_media_attachments,
        type: :integer,
        description: "Maximum number of post media attachments",
        suggestions: [
          1_000_000
        ]
      },
      %{
        key: :upload_limit,
        type: :integer,
        description: "File size limit of uploads (except for avatar, background, banner)",
        suggestions: [
          16_000_000
        ]
      },
      %{
        key: :avatar_upload_limit,
        type: :integer,
        description: "File size limit of user's profile avatars",
        suggestions: [
          2_000_000
        ]
      },
      %{
        key: :background_upload_limit,
        type: :integer,
        description: "File size limit of user's profile backgrounds",
        suggestions: [
          4_000_000
        ]
      },
      %{
        key: :banner_upload_limit,
        type: :integer,
        description: "File size limit of user's profile banners",
        suggestions: [
          4_000_000
        ]
      },
      %{
        key: :poll_limits,
        type: :map,
        description: "A map with poll limits for local polls",
        suggestions: [
          %{
            max_options: 20,
            max_option_chars: 200,
            min_expiration: 0,
            max_expiration: 31_536_000
          }
        ],
        children: [
          %{
            key: :max_options,
            type: :integer,
            description: "Maximum number of options",
            suggestions: [20]
          },
          %{
            key: :max_option_chars,
            type: :integer,
            description: "Maximum number of characters per option",
            suggestions: [200]
          },
          %{
            key: :min_expiration,
            type: :integer,
            description: "Minimum expiration time (in seconds)",
            suggestions: [0]
          },
          %{
            key: :max_expiration,
            type: :integer,
            description: "Maximum expiration time (in seconds)",
            suggestions: [3600]
          }
        ]
      },
      %{
        key: :registrations_open,
        type: :boolean,
        description:
          "Enable registrations for anyone. Invitations require this setting to be disabled."
      },
      %{
        key: :invites_enabled,
        type: :boolean,
        description:
          "Enable user invitations for admins (depends on `registrations_open` being disabled)"
      },
      %{
        key: :account_activation_required,
        type: :boolean,
        description: "Require users to confirm their emails before signing in"
      },
      %{
        key: :account_approval_required,
        type: :boolean,
        description: "Require users to be manually approved by an admin before signing in"
      },
      %{
        key: :federating,
        type: :boolean,
        description: "Enable federation with other instances"
      },
      %{
        key: :federation_incoming_replies_max_depth,
        label: "Fed. incoming replies max depth",
        type: :integer,
        description:
          "Max. depth of reply-to and reply activities fetching on incoming federation, to prevent out-of-memory situations while" <>
            " fetching very long threads. If set to `nil`, threads of any depth will be fetched. Lower this value if you experience out-of-memory crashes.",
        suggestions: [
          100
        ]
      },
      %{
        key: :federation_reachability_timeout_days,
        label: "Fed. reachability timeout days",
        type: :integer,
        description:
          "Timeout (in days) of each external federation target being unreachable prior to pausing federating to it",
        suggestions: [
          7
        ]
      },
      %{
        key: :allow_relay,
        type: :boolean,
        description:
          "Permits remote instances to subscribe to all public posts of your instance. (Important!) This may increase the visibility of your instance."
      },
      %{
        key: :public,
        type: :boolean,
        description:
          "Makes the client API in authenticated mode-only except for user-profiles." <>
            " Useful for disabling the Local Timeline and The Whole Known Network. " <>
            " Note: when setting to `false`, please also check `:restrict_unauthenticated` setting."
      },
      %{
        key: :quarantined_instances,
        type: {:list, :tuple},
        key_placeholder: "instance",
        value_placeholder: "reason",
        description:
          "List of ActivityPub instances where private (DMs, followers-only) activities will not be sent and the reason for doing so",
        suggestions: [
          {"quarantined.com", "Reason"},
          {"*.quarantined.com", "Reason"}
        ]
      },
      %{
        key: :static_dir,
        type: :string,
        description: "Instance static directory",
        suggestions: [
          "instance/static/"
        ]
      },
      %{
        key: :allowed_post_formats,
        type: {:list, :string},
        description: "MIME-type list of formats allowed to be posted (transformed into HTML)",
        suggestions: [
          "text/plain",
          "text/html",
          "text/markdown",
          "text/bbcode"
        ]
      },
      %{
        key: :extended_nickname_format,
        type: :boolean,
        description:
          "Enable to use extended local nicknames format (allows underscores/dashes)." <>
            " This will break federation with older software for theses nicknames."
      },
      %{
        key: :cleanup_attachments,
        type: :boolean,
        description: """
        Enable to remove associated attachments when status is removed.
        This will not affect duplicates and attachments without status.
        Enabling this will increase load to database when deleting statuses on larger instances.
        """
      },
      %{
        key: :max_pinned_statuses,
        type: :integer,
        description: "The maximum number of pinned statuses. 0 will disable the feature.",
        suggestions: [
          0,
          1,
          3
        ]
      },
      %{
        key: :max_endorsed_users,
        type: :integer,
        description: "The maximum number of recommended accounts. 0 will disable the feature.",
        suggestions: [
          0,
          1,
          3
        ]
      },
      %{
        key: :autofollowed_nicknames,
        type: {:list, :string},
        description:
          "Set to nicknames of (local) users that every new user should automatically follow"
      },
      %{
        key: :autofollowing_nicknames,
        type: {:list, :string},
        description:
          "Set to nicknames of (local) users that automatically follows every newly registered user"
      },
      %{
        key: :attachment_links,
        type: :boolean,
        description: "Enable to automatically add attachment link text to statuses"
      },
      %{
        key: :max_report_comment_size,
        type: :integer,
        description: "The maximum size of the report comment. Default: 1000.",
        suggestions: [
          1_000
        ]
      },
      %{
        key: :safe_dm_mentions,
        label: "Safe DM mentions",
        type: :boolean,
        description:
          "If enabled, only mentions at the beginning of a post will be used to address people in direct messages." <>
            " This is to prevent accidental mentioning of people when talking about them (e.g. \"@admin please keep an eye on @bad_actor\")." <>
            " Default: disabled"
      },
      %{
        key: :healthcheck,
        type: :boolean,
        description: "If enabled, system data will be shown on `/api/pleroma/healthcheck`"
      },
      %{
        key: :remote_post_retention_days,
        type: :integer,
        description:
          "The default amount of days to retain remote posts when pruning the database",
        suggestions: [
          90
        ]
      },
      %{
        key: :user_bio_length,
        type: :integer,
        description: "A user bio maximum length. Default: 5000.",
        suggestions: [
          5_000
        ]
      },
      %{
        key: :user_name_length,
        type: :integer,
        description: "A user name maximum length. Default: 100.",
        suggestions: [
          100
        ]
      },
      %{
        key: :skip_thread_containment,
        type: :boolean,
        description: "Skip filtering out broken threads. Default: enabled."
      },
      %{
        key: :limit_to_local_content,
        type: {:dropdown, :atom},
        description:
          "Limit unauthenticated users to search for local statutes and users only. Default: `:unauthenticated`.",
        suggestions: [
          :unauthenticated,
          :all,
          false
        ]
      },
      %{
        key: :max_account_fields,
        type: :integer,
        description: "The maximum number of custom fields in the user profile. Default: 10.",
        suggestions: [
          10
        ]
      },
      %{
        key: :max_remote_account_fields,
        type: :integer,
        description:
          "The maximum number of custom fields in the remote user profile. Default: 20.",
        suggestions: [
          20
        ]
      },
      %{
        key: :account_field_name_length,
        type: :integer,
        description: "An account field name maximum length. Default: 512.",
        suggestions: [
          512
        ]
      },
      %{
        key: :account_field_value_length,
        type: :integer,
        description: "An account field value maximum length. Default: 2048.",
        suggestions: [
          2048
        ]
      },
      %{
        key: :registration_reason_length,
        type: :integer,
        description: "Maximum registration reason length. Default: 500.",
        suggestions: [
          500
        ]
      },
      %{
        key: :external_user_synchronization,
        type: :boolean,
        description: "Enabling following/followers counters synchronization for external users"
      },
      %{
        key: :multi_factor_authentication,
        type: :keyword,
        description: "Multi-factor authentication settings",
        suggestions: [
          [
            totp: [digits: 6, period: 30],
            backup_codes: [number: 5, length: 16]
          ]
        ],
        children: [
          %{
            key: :totp,
            label: "TOTP settings",
            type: :keyword,
            description: "TOTP settings",
            suggestions: [digits: 6, period: 30],
            children: [
              %{
                key: :digits,
                type: :integer,
                suggestions: [6],
                description:
                  "Determines the length of a one-time pass-code, in characters. Defaults to 6 characters."
              },
              %{
                key: :period,
                type: :integer,
                suggestions: [30],
                description:
                  "A period for which the TOTP code will be valid, in seconds. Defaults to 30 seconds."
              }
            ]
          },
          %{
            key: :backup_codes,
            type: :keyword,
            description: "MFA backup codes settings",
            suggestions: [number: 5, length: 16],
            children: [
              %{
                key: :number,
                type: :integer,
                suggestions: [5],
                description: "Number of backup codes to generate."
              },
              %{
                key: :length,
                type: :integer,
                suggestions: [16],
                description:
                  "Determines the length of backup one-time pass-codes, in characters. Defaults to 16 characters."
              }
            ]
          }
        ]
      },
      %{
        key: :instance_thumbnail,
        type: {:string, :image},
        description:
          "The instance thumbnail can be any image that represents your instance and is used by some apps or services when they display information about your instance.",
        suggestions: ["/instance/thumbnail.jpeg"]
      },
      %{
        key: :show_reactions,
        type: :boolean,
        description: "Let favourites and emoji reactions be viewed through the API."
      },
      %{
        key: :profile_directory,
        type: :boolean,
        description: "Enable profile directory."
      },
      %{
        key: :privileged_staff,
        type: :boolean,
        description:
          "Let moderators access sensitive data (e.g. updating user credentials, get password reset token, delete users, index and read private statuses and chats)"
      },
      %{
        key: :birthday_required,
        type: :boolean,
        description: "Require users to enter their birthday."
      },
      %{
        key: :birthday_min_age,
        type: :integer,
        description:
          "Minimum required age for users to create account. Only used if birthday is required."
      }
    ]
  },
  %{
    group: :pleroma,
    key: :welcome,
    type: :group,
    description: "Welcome messages settings",
    children: [
      %{
        key: :direct_message,
        type: :keyword,
        descpiption: "Direct message settings",
        children: [
          %{
            key: :enabled,
            type: :boolean,
            description: "Enables sending a direct message to newly registered users"
          },
          %{
            key: :message,
            type: :string,
            description: "A message that will be sent to newly registered users",
            suggestions: [
              "Hi, @username! Welcome on board!"
            ]
          },
          %{
            key: :sender_nickname,
            type: :string,
            description: "The nickname of the local user that sends a welcome message",
            suggestions: [
              "lain"
            ]
          }
        ]
      },
      %{
        key: :chat_message,
        type: :keyword,
        descpiption: "Chat message settings",
        children: [
          %{
            key: :enabled,
            type: :boolean,
            description: "Enables sending a chat message to newly registered users"
          },
          %{
            key: :message,
            type: :string,
            description:
              "A message that will be sent to newly registered users as a chat message",
            suggestions: [
              "Hello, welcome on board!"
            ]
          },
          %{
            key: :sender_nickname,
            type: :string,
            description: "The nickname of the local user that sends a welcome chat message",
            suggestions: [
              "lain"
            ]
          }
        ]
      },
      %{
        key: :email,
        type: :keyword,
        descpiption: "Email message settings",
        children: [
          %{
            key: :enabled,
            type: :boolean,
            description: "Enables sending an email to newly registered users"
          },
          %{
            key: :sender,
            type: [:string, :tuple],
            description:
              "Email address and/or nickname that will be used to send the welcome email.",
            suggestions: [
              {"Pleroma App", "welcome@pleroma.app"}
            ]
          },
          %{
            key: :subject,
            type: :string,
            description:
              "Subject of the welcome email. EEX template with user and instance_name variables can be used.",
            suggestions: ["Welcome to <%= instance_name%>"]
          },
          %{
            key: :html,
            type: :string,
            description:
              "HTML content of the welcome email. EEX template with user and instance_name variables can be used.",
            suggestions: ["<h1>Hello <%= user.name%>. Welcome to <%= instance_name%></h1>"]
          },
          %{
            key: :text,
            type: :string,
            description:
              "Text content of the welcome email. EEX template with user and instance_name variables can be used.",
            suggestions: ["Hello <%= user.name%>. \n Welcome to <%= instance_name%>\n"]
          }
        ]
      }
    ]
  },
  %{
    group: :logger,
    type: :group,
    description: "Logger-related settings",
    children: [
      %{
        key: :backends,
        type: [:atom, :tuple, :module],
        description:
          "Where logs will be sent, :console - send logs to stdout, { ExSyslogger, :ex_syslogger } - to syslog, Quack.Logger - to Slack.",
        suggestions: [:console, {ExSyslogger, :ex_syslogger}, Quack.Logger]
      }
    ]
  },
  %{
    group: :logger,
    type: :group,
    key: :ex_syslogger,
    label: "ExSyslogger",
    description: "ExSyslogger-related settings",
    children: [
      %{
        key: :level,
        type: {:dropdown, :atom},
        description: "Log level",
        suggestions: [:debug, :info, :warn, :error]
      },
      %{
        key: :ident,
        type: :string,
        description:
          "A string that's prepended to every message, and is typically set to the app name",
        suggestions: ["pleroma"]
      },
      %{
        key: :format,
        type: :string,
        description: "Default: \"$date $time [$level] $levelpad$node $metadata $message\"",
        suggestions: ["$metadata[$level] $message"]
      },
      %{
        key: :metadata,
        type: {:list, :atom},
        suggestions: [:request_id]
      }
    ]
  },
  %{
    group: :logger,
    type: :group,
    key: :console,
    label: "Console Logger",
    description: "Console logger settings",
    children: [
      %{
        key: :level,
        type: {:dropdown, :atom},
        description: "Log level",
        suggestions: [:debug, :info, :warn, :error]
      },
      %{
        key: :format,
        type: :string,
        description: "Default: \"$date $time [$level] $levelpad$node $metadata $message\"",
        suggestions: ["$metadata[$level] $message"]
      },
      %{
        key: :metadata,
        type: {:list, :atom},
        suggestions: [:request_id]
      }
    ]
  },
  %{
    group: :quack,
    type: :group,
    label: "Quack Logger",
    description: "Quack-related settings",
    children: [
      %{
        key: :level,
        type: {:dropdown, :atom},
        description: "Log level",
        suggestions: [:debug, :info, :warn, :error]
      },
      %{
        key: :meta,
        type: {:list, :atom},
        description: "Configure which metadata you want to report on",
        suggestions: [
          :application,
          :module,
          :file,
          :function,
          :line,
          :pid,
          :crash_reason,
          :initial_call,
          :registered_name,
          :all,
          :none
        ]
      },
      %{
        key: :webhook_url,
        label: "Webhook URL",
        type: :string,
        description: "Configure the Slack incoming webhook",
        suggestions: ["https://hooks.slack.com/services/YOUR-KEY-HERE"]
      }
    ]
  },
  %{
    group: :pleroma,
    key: :frontend_configurations,
    type: :group,
    description:
      "This form can be used to configure a keyword list that keeps the configuration data for any " <>
        "kind of frontend. By default, settings for pleroma_fe are configured. If you want to " <>
        "add your own configuration your settings all fields must be complete.",
    children: [
      %{
        key: :pleroma_fe,
        label: "Pleroma FE",
        type: :map,
        description: "Settings for Pleroma FE",
        suggestions: [
          %{
            alwaysShowSubjectInput: true,
            background: "/static/aurora_borealis.jpg",
            collapseMessageWithSubject: false,
            greentext: false,
            hideFilteredStatuses: false,
            hideMutedPosts: false,
            hidePostStats: false,
            hideSitename: false,
            hideUserStats: false,
            loginMethod: "password",
            logo: "/static/logo.svg",
            logoMargin: ".1em",
            logoMask: true,
            minimalScopesMode: false,
            noAttachmentLinks: false,
            nsfwCensorImage: "/static/img/nsfw.74818f9.png",
            postContentType: "text/plain",
            redirectRootLogin: "/main/friends",
            redirectRootNoLogin: "/main/all",
            scopeCopy: true,
            sidebarRight: false,
            showFeaturesPanel: true,
            showInstanceSpecificPanel: false,
            subjectLineBehavior: "email",
            theme: "pleroma-dark",
            webPushNotifications: false
          }
        ],
        children: [
          %{
            key: :alwaysShowSubjectInput,
            label: "Always show subject input",
            type: :boolean,
            description: "When disabled, auto-hide the subject field if it's empty"
          },
          %{
            key: :background,
            type: {:string, :image},
            description:
              "URL of the background, unless viewing a user profile with a background that is set",
            suggestions: ["/images/city.jpg"]
          },
          %{
            key: :collapseMessageWithSubject,
            label: "Collapse message with subject",
            type: :boolean,
            description:
              "When a message has a subject (aka Content Warning), collapse it by default"
          },
          %{
            key: :greentext,
            label: "Greentext",
            type: :boolean,
            description: "Enables green text on lines prefixed with the > character"
          },
          %{
            key: :hideFilteredStatuses,
            label: "Hide Filtered Statuses",
            type: :boolean,
            description: "Hides filtered statuses from timelines"
          },
          %{
            key: :hideMutedPosts,
            label: "Hide Muted Posts",
            type: :boolean,
            description: "Hides muted statuses from timelines"
          },
          %{
            key: :hidePostStats,
            label: "Hide post stats",
            type: :boolean,
            description: "Hide notices statistics (repeats, favorites, ...)"
          },
          %{
            key: :hideSitename,
            label: "Hide Sitename",
            type: :boolean,
            description: "Hides instance name from PleromaFE banner"
          },
          %{
            key: :hideUserStats,
            label: "Hide user stats",
            type: :boolean,
            description:
              "Hide profile statistics (posts, posts per day, followers, followings, ...)"
          },
          %{
            key: :logo,
            type: {:string, :image},
            description: "URL of the logo, defaults to Pleroma's logo",
            suggestions: ["/static/logo.svg"]
          },
          %{
            key: :logoMargin,
            label: "Logo margin",
            type: :string,
            description:
              "Allows you to adjust vertical margins between logo boundary and navbar borders. " <>
                "The idea is that to have logo's image without any extra margins and instead adjust them to your need in layout.",
            suggestions: [".1em"]
          },
          %{
            key: :logoMask,
            label: "Logo mask",
            type: :boolean,
            description:
              "By default it assumes logo used will be monochrome with alpha channel to be compatible with both light and dark themes. " <>
                "If you want a colorful logo you must disable logoMask."
          },
          %{
            key: :minimalScopesMode,
            label: "Minimal scopes mode",
            type: :boolean,
            description:
              "Limit scope selection to Direct, User default, and Scope of post replying to. " <>
                "Also prevents replying to a DM with a public post from PleromaFE."
          },
          %{
            key: :nsfwCensorImage,
            label: "NSFW Censor Image",
            type: {:string, :image},
            description:
              "URL of the image to use for hiding NSFW media attachments in the timeline",
            suggestions: ["/static/img/nsfw.74818f9.png"]
          },
          %{
            key: :postContentType,
            label: "Post Content Type",
            type: {:dropdown, :atom},
            description: "Default post formatting option",
            suggestions: ["text/plain", "text/html", "text/markdown", "text/bbcode"]
          },
          %{
            key: :redirectRootNoLogin,
            label: "Redirect root no login",
            type: :string,
            description:
              "Relative URL which indicates where to redirect when a user isn't logged in",
            suggestions: ["/main/all"]
          },
          %{
            key: :redirectRootLogin,
            label: "Redirect root login",
            type: :string,
            description:
              "Relative URL which indicates where to redirect when a user is logged in",
            suggestions: ["/main/friends"]
          },
          %{
            key: :scopeCopy,
            label: "Scope copy",
            type: :boolean,
            description: "Copy the scope (private/unlisted/public) in replies to posts by default"
          },
          %{
            key: :sidebarRight,
            label: "Sidebar on Right",
            type: :boolean,
            description: "Change alignment of sidebar and panels to the right"
          },
          %{
            key: :showFeaturesPanel,
            label: "Show instance features panel",
            type: :boolean,
            description:
              "Enables panel displaying functionality of the instance on the About page"
          },
          %{
            key: :showInstanceSpecificPanel,
            label: "Show instance specific panel",
            type: :boolean,
            description: "Whether to show the instance's custom panel"
          },
          %{
            key: :subjectLineBehavior,
            label: "Subject line behavior",
            type: :string,
            description: "Allows changing the default behaviour of subject lines in replies.
          `email`: copy and preprend re:, as in email,
          `masto`: copy verbatim, as in Mastodon,
          `noop`: don't copy the subject.",
            suggestions: ["email", "masto", "noop"]
          },
          %{
            key: :theme,
            type: :string,
            description: "Which theme to use. Available themes are defined in styles.json",
            suggestions: ["pleroma-dark"]
          }
        ]
      }
    ]
  },
  %{
    group: :pleroma,
    key: :assets,
    type: :group,
    description:
      "This section configures assets to be used with various frontends. Currently the only option relates to mascots on the mastodon frontend",
    children: [
      %{
        key: :mascots,
        type: {:keyword, :map},
        description:
          "Keyword of mascots, each element must contain both an URL and a mime_type key",
        suggestions: [
          pleroma_fox_tan: %{
            url: "/images/pleroma-fox-tan-smol.png",
            mime_type: "image/png"
          },
          pleroma_fox_tan_shy: %{
            url: "/images/pleroma-fox-tan-shy.png",
            mime_type: "image/png"
          }
        ]
      },
      %{
        key: :default_mascot,
        type: :atom,
        description:
          "This will be used as the default mascot on MastoFE. Default: `:pleroma_fox_tan`",
        suggestions: [
          :pleroma_fox_tan
        ]
      },
      %{
        key: :default_user_avatar,
        type: {:string, :image},
        description: "URL of the default user avatar",
        suggestions: ["/images/avi.png"]
      }
    ]
  },
  %{
    group: :pleroma,
    key: :manifest,
    type: :group,
    description:
      "This section describe PWA manifest instance-specific values. Currently this option relate only for MastoFE.",
    children: [
      %{
        key: :icons,
        type: {:list, :map},
        description: "Describe the icons of the app",
        suggestion: [
          %{
            src: "/static/logo.png"
          },
          %{
            src: "/static/icon.png",
            type: "image/png"
          },
          %{
            src: "/static/icon.ico",
            sizes: "72x72 96x96 128x128 256x256"
          }
        ]
      },
      %{
        key: :theme_color,
        type: :string,
        description: "Describe the theme color of the app",
        suggestions: ["#282c37", "mediumpurple"]
      },
      %{
        key: :background_color,
        type: :string,
        description: "Describe the background color of the app",
        suggestions: ["#191b22", "aliceblue"]
      }
    ]
  },
  %{
    group: :pleroma,
    key: :media_proxy,
    type: :group,
    description: "Media proxy",
    children: [
      %{
        key: :enabled,
        type: :boolean,
        description: "Enables proxying of remote media via the instance's proxy"
      },
      %{
        key: :base_url,
        label: "Base URL",
        type: :string,
        description:
          "The base URL to access a user-uploaded file. Useful when you want to proxy the media files via another host/CDN fronts.",
        suggestions: ["https://example.com"]
      },
      %{
        key: :invalidation,
        type: :keyword,
        descpiption: "",
        suggestions: [
          enabled: true,
          provider: Pleroma.Web.MediaProxy.Invalidation.Script
        ],
        children: [
          %{
            key: :enabled,
            type: :boolean,
            description: "Enables media cache object invalidation."
          },
          %{
            key: :provider,
            type: :module,
            description: "Module which will be used to purge objects from the cache.",
            suggestions: [
              Pleroma.Web.MediaProxy.Invalidation.Script,
              Pleroma.Web.MediaProxy.Invalidation.Http
            ]
          }
        ]
      },
      %{
        key: :proxy_opts,
        label: "Advanced MediaProxy Options",
        type: :keyword,
        description: "Internal Pleroma.ReverseProxy settings",
        suggestions: [
          redirect_on_failure: false,
          max_body_length: 25 * 1_048_576,
          max_read_duration: 30_000
        ],
        children: [
          %{
            key: :redirect_on_failure,
            type: :boolean,
            description: """
            Redirects the client to the origin server upon encountering HTTP errors.\n
            Note that files larger than Max Body Length will trigger an error. (e.g., Peertube videos)\n\n
            **WARNING:** This setting will allow larger files to be accessed, but exposes the\n
            IP addresses of your users to the other servers, bypassing the MediaProxy.
            """
          },
          %{
            key: :max_body_length,
            type: :integer,
            description:
              "Maximum file size (in bytes) allowed through the Pleroma MediaProxy cache."
          },
          %{
            key: :max_read_duration,
            type: :integer,
            description: "Timeout (in milliseconds) of GET request to the remote URI."
          }
        ]
      },
      %{
        key: :whitelist,
        type: {:list, :string},
        description: "List of hosts with scheme to bypass the MediaProxy",
        suggestions: ["http://example.com"]
      }
    ]
  },
  %{
    group: :pleroma,
    key: :media_preview_proxy,
    type: :group,
    description: "Media preview proxy",
    children: [
      %{
        key: :enabled,
        type: :boolean,
        description:
          "Enables proxying of remote media preview to the instance's proxy. Requires enabled media proxy."
      },
      %{
        key: :thumbnail_max_width,
        type: :integer,
        description:
          "Max width of preview thumbnail for images (video preview always has original dimensions)."
      },
      %{
        key: :thumbnail_max_height,
        type: :integer,
        description:
          "Max height of preview thumbnail for images (video preview always has original dimensions)."
      },
      %{
        key: :image_quality,
        type: :integer,
        description: "Quality of the output. Ranges from 0 (min quality) to 100 (max quality)."
      },
      %{
        key: :min_content_length,
        type: :integer,
        description:
          "Min content length (in bytes) to perform preview. Media smaller in size will be served without thumbnailing."
      }
    ]
  },
  %{
    group: :pleroma,
    key: Pleroma.Web.MediaProxy.Invalidation.Http,
    type: :group,
    description: "HTTP invalidate settings",
    children: [
      %{
        key: :method,
        type: :atom,
        description: "HTTP method of request. Default: :purge"
      },
      %{
        key: :headers,
        type: {:keyword, :string},
        description: "HTTP headers of request",
        suggestions: [{"x-refresh", 1}]
      },
      %{
        key: :options,
        type: :keyword,
        description: "Request options",
        children: [
          %{
            key: :params,
            type: {:map, :string}
          }
        ]
      }
    ]
  },
  %{
    group: :pleroma,
    key: Pleroma.Web.MediaProxy.Invalidation.Script,
    type: :group,
    description: "Invalidation script settings",
    children: [
      %{
        key: :script_path,
        type: :string,
        description: "Path to executable script which will purge cached items.",
        suggestions: ["./installation/nginx-cache-purge.sh.example"]
      },
      %{
        key: :url_format,
        label: "URL Format",
        type: :string,
        description:
          "Optional URL format preprocessing. Only required for Apache's htcacheclean.",
        suggestions: [":htcacheclean"]
      }
    ]
  },
  %{
    group: :pleroma,
    key: :gopher,
    type: :group,
    description: "Gopher settings",
    children: [
      %{
        key: :enabled,
        type: :boolean,
        description: "Enables the gopher interface"
      },
      %{
        key: :ip,
        label: "IP",
        type: :tuple,
        description: "IP address to bind to",
        suggestions: [{0, 0, 0, 0}]
      },
      %{
        key: :port,
        type: :integer,
        description: "Port to bind to",
        suggestions: [9999]
      },
      %{
        key: :dstport,
        type: :integer,
        description: "Port advertised in URLs (optional, defaults to port)",
        suggestions: [9999]
      }
    ]
  },
  %{
    group: :pleroma,
    key: :activitypub,
    label: "ActivityPub",
    type: :group,
    description: "ActivityPub-related settings",
    children: [
      %{
        key: :unfollow_blocked,
        type: :boolean,
        description: "Whether blocks result in people getting unfollowed"
      },
      %{
        key: :outgoing_blocks,
        type: :boolean,
        description: "Whether to federate blocks to other instances"
      },
      %{
        key: :blockers_visible,
        type: :boolean,
        description: "Whether a user can see someone who has blocked them"
      },
      %{
        key: :sign_object_fetches,
        type: :boolean,
        description: "Sign object fetches with HTTP signatures"
      },
      %{
        key: :note_replies_output_limit,
        type: :integer,
        description:
          "The number of Note replies' URIs to be included with outgoing federation (`5` to match Mastodon hardcoded value, `0` to disable the output)"
      },
      %{
        key: :follow_handshake_timeout,
        type: :integer,
        description: "Following handshake timeout",
        suggestions: [500]
      }
    ]
  },
  %{
    group: :pleroma,
    key: :http_security,
    label: "HTTP security",
    type: :group,
    description: "HTTP security settings",
    children: [
      %{
        key: :enabled,
        type: :boolean,
        description: "Whether the managed content security policy is enabled"
      },
      %{
        key: :sts,
        label: "STS",
        type: :boolean,
        description: "Whether to additionally send a Strict-Transport-Security header"
      },
      %{
        key: :sts_max_age,
        label: "STS max age",
        type: :integer,
        description: "The maximum age for the Strict-Transport-Security header if sent",
        suggestions: [31_536_000]
      },
      %{
        key: :ct_max_age,
        label: "CT max age",
        type: :integer,
        description: "The maximum age for the Expect-CT header if sent",
        suggestions: [2_592_000]
      },
      %{
        key: :referrer_policy,
        type: :string,
        description: "The referrer policy to use, either \"same-origin\" or \"no-referrer\"",
        suggestions: ["same-origin", "no-referrer"]
      },
      %{
        key: :report_uri,
        label: "Report URI",
        type: :string,
        description: "Adds the specified URL to report-uri and report-to group in CSP header",
        suggestions: ["https://example.com/report-uri"]
      }
    ]
  },
  %{
    group: :web_push_encryption,
    key: :vapid_details,
    label: "Vapid Details",
    type: :group,
    description:
      "Web Push Notifications configuration. You can use the mix task mix web_push.gen.keypair to generate it.",
    children: [
      %{
        key: :subject,
        type: :string,
        description:
          "A mailto link for the administrative contact." <>
            " It's best if this email is not a personal email address, but rather a group email to the instance moderation team.",
        suggestions: ["mailto:moderators@pleroma.com"]
      },
      %{
        key: :public_key,
        type: :string,
        description: "VAPID public key",
        suggestions: ["Public key"]
      },
      %{
        key: :private_key,
        type: :string,
        description: "VAPID private key",
        suggestions: ["Private key"]
      }
    ]
  },
  %{
    group: :pleroma,
    key: Pleroma.Captcha,
    type: :group,
    description: "Captcha-related settings",
    children: [
      %{
        key: :enabled,
        type: :boolean,
        description: "Whether the captcha should be shown on registration"
      },
      %{
        key: :method,
        type: :module,
        description: "The method/service to use for captcha",
        suggestions: [Pleroma.Captcha.Kocaptcha, Pleroma.Captcha.Native]
      },
      %{
        key: :seconds_valid,
        type: :integer,
        description: "The time in seconds for which the captcha is valid",
        suggestions: [60]
      }
    ]
  },
  %{
    group: :pleroma,
    key: Pleroma.Captcha.Kocaptcha,
    type: :group,
    description:
      "Kocaptcha is a very simple captcha service with a single API endpoint, the source code is" <>
        " here: https://github.com/koto-bank/kocaptcha. The default endpoint (https://captcha.kotobank.ch) is hosted by the developer.",
    children: [
      %{
        key: :endpoint,
        type: :string,
        description: "The kocaptcha endpoint to use",
        suggestions: ["https://captcha.kotobank.ch"]
      }
    ]
  },
  %{
    group: :pleroma,
    label: "Pleroma Admin Token",
    type: :group,
    description:
      "Allows setting a token that can be used to authenticate requests with admin privileges without a normal user account token. Append the `admin_token` parameter to requests to utilize it. (Please reconsider using HTTP Basic Auth or OAuth-based authentication if possible)",
    children: [
      %{
        key: :admin_token,
        type: :string,
        description: "Admin token",
        suggestions: [
          "Please use a high entropy string or UUID"
        ]
      }
    ]
  },
  %{
    group: :pleroma,
    key: Oban,
    type: :group,
    description:
      "[Oban](https://github.com/sorentwo/oban) asynchronous job processor configuration.",
    children: [
      %{
        key: :log,
        type: {:dropdown, :atom},
        description: "Logs verbose mode",
        suggestions: [false, :error, :warn, :info, :debug]
      },
      %{
        key: :queues,
        type: {:keyword, :integer},
        description:
          "Background jobs queues (keys: queues, values: max numbers of concurrent jobs)",
        suggestions: [
          activity_expiration: 10,
          attachments_cleanup: 5,
          background: 5,
          federator_incoming: 50,
          federator_outgoing: 50,
          mailer: 10,
          scheduled_activities: 10,
          transmogrifier: 20,
          web_push: 50
        ],
        children: [
          %{
            key: :activity_expiration,
            type: :integer,
            description: "Activity expiration queue",
            suggestions: [10]
          },
          %{
            key: :backup,
            type: :integer,
            description: "Backup queue",
            suggestions: [1]
          },
          %{
            key: :attachments_cleanup,
            type: :integer,
            description: "Attachment deletion queue",
            suggestions: [5]
          },
          %{
            key: :background,
            type: :integer,
            description: "Background queue",
            suggestions: [5]
          },
          %{
            key: :federator_incoming,
            type: :integer,
            description: "Incoming federation queue",
            suggestions: [50]
          },
          %{
            key: :federator_outgoing,
            type: :integer,
            description: "Outgoing federation queue",
            suggestions: [50]
          },
          %{
            key: :mailer,
            type: :integer,
            description: "Email sender queue, see Pleroma.Emails.Mailer",
            suggestions: [10]
          },
          %{
            key: :scheduled_activities,
            type: :integer,
            description: "Scheduled activities queue, see Pleroma.ScheduledActivities",
            suggestions: [10]
          },
          %{
            key: :transmogrifier,
            type: :integer,
            description: "Transmogrifier queue",
            suggestions: [20]
          },
          %{
            key: :web_push,
            type: :integer,
            description: "Web push notifications queue",
            suggestions: [50]
          }
        ]
      },
      %{
        key: :crontab,
        type: {:list, :tuple},
        description: "Settings for cron background jobs",
        suggestions: [
          {"0 0 * * 0", Pleroma.Workers.Cron.DigestEmailsWorker},
          {"0 0 * * *", Pleroma.Workers.Cron.NewUsersDigestWorker}
        ]
      }
    ]
  },
  %{
    group: :pleroma,
    key: :workers,
    type: :group,
    description: "Includes custom worker options not interpretable directly by `Oban`",
    children: [
      %{
        key: :retries,
        type: {:keyword, :integer},
        description: "Max retry attempts for failed jobs, per `Oban` queue",
        suggestions: [
          federator_incoming: 5,
          federator_outgoing: 5
        ]
      }
    ]
  },
  %{
    group: :pleroma,
    key: Pleroma.Web.Metadata,
    type: :group,
    description: "Metadata-related settings",
    children: [
      %{
        key: :providers,
        type: {:list, :module},
        description: "List of metadata providers to enable",
        suggestions: [
          Pleroma.Web.Metadata.Providers.OpenGraph,
          Pleroma.Web.Metadata.Providers.TwitterCard,
          Pleroma.Web.Metadata.Providers.RelMe,
          Pleroma.Web.Metadata.Providers.Feed
        ]
      },
      %{
        key: :unfurl_nsfw,
        label: "Unfurl NSFW",
        type: :boolean,
        description: "When enabled NSFW attachments will be shown in previews"
      }
    ]
  },
  %{
    group: :pleroma,
    key: :rich_media,
    type: :group,
    description:
      "If enabled the instance will parse metadata from attached links to generate link previews",
    children: [
      %{
        key: :enabled,
        type: :boolean,
        description: "Enables RichMedia parsing of URLs"
      },
      %{
        key: :ignore_hosts,
        type: {:list, :string},
        description: "List of hosts which will be ignored by the metadata parser",
        suggestions: ["accounts.google.com", "xss.website"]
      },
      %{
        key: :ignore_tld,
        label: "Ignore TLD",
        type: {:list, :string},
        description: "List TLDs (top-level domains) which will ignore for parse metadata",
        suggestions: ["local", "localdomain", "lan"]
      },
      %{
        key: :parsers,
        type: {:list, :module},
        description:
          "List of Rich Media parsers. Module names are shortened (removed leading `Pleroma.Web.RichMedia.Parsers.` part), but on adding custom module you need to use full name.",
        suggestions: [
          Pleroma.Web.RichMedia.Parsers.OEmbed,
          Pleroma.Web.RichMedia.Parsers.TwitterCard
        ]
      },
      %{
        key: :ttl_setters,
        label: "TTL setters",
        type: {:list, :module},
        description:
          "List of rich media TTL setters. Module names are shortened (removed leading `Pleroma.Web.RichMedia.Parser.` part), but on adding custom module you need to use full name.",
        suggestions: [
          Pleroma.Web.RichMedia.Parser.TTL.AwsSignedUrl
        ]
      },
      %{
        key: :failure_backoff,
        type: :integer,
        description:
          "Amount of milliseconds after request failure, during which the request will not be retried.",
        suggestions: [60_000]
      }
    ]
  },
  %{
    group: :pleroma,
    key: Pleroma.Formatter,
    label: "Linkify",
    type: :group,
    description:
      "Configuration for Pleroma's link formatter which parses mentions, hashtags, and URLs.",
    children: [
      %{
        key: :class,
        type: [:string, :boolean],
        description: "Specify the class to be added to the generated link. Disable to clear.",
        suggestions: ["auto-linker", false]
      },
      %{
        key: :rel,
        type: [:string, :boolean],
        description: "Override the rel attribute. Disable to clear.",
        suggestions: ["ugc", "noopener noreferrer", false]
      },
      %{
        key: :new_window,
        type: :boolean,
        description: "Link URLs will open in a new window/tab."
      },
      %{
        key: :truncate,
        type: [:integer, :boolean],
        description:
          "Set to a number to truncate URLs longer than the number. Truncated URLs will end in `...`",
        suggestions: [15, false]
      },
      %{
        key: :strip_prefix,
        type: :boolean,
        description: "Strip the scheme prefix."
      },
      %{
        key: :extra,
        type: :boolean,
        description: "Link URLs with rarely used schemes (magnet, ipfs, irc, etc.)"
      },
      %{
        key: :validate_tld,
        type: [:atom, :boolean],
        description:
          "Set to false to disable TLD validation for URLs/emails. Can be set to :no_scheme to validate TLDs only for URLs without a scheme (e.g `example.com` will be validated, but `http://example.loki` won't)",
        suggestions: [:no_scheme, true]
      }
    ]
  },
  %{
    group: :pleroma,
    key: Pleroma.ScheduledActivity,
    type: :group,
    description: "Scheduled activities settings",
    children: [
      %{
        key: :daily_user_limit,
        type: :integer,
        description:
          "The number of scheduled activities a user is allowed to create in a single day. Default: 25.",
        suggestions: [25]
      },
      %{
        key: :total_user_limit,
        type: :integer,
        description:
          "The number of scheduled activities a user is allowed to create in total. Default: 300.",
        suggestions: [300]
      },
      %{
        key: :enabled,
        type: :boolean,
        description: "Whether scheduled activities are sent to the job queue to be executed"
      }
    ]
  },
  %{
    group: :pleroma,
    key: Pleroma.Workers.PurgeExpiredActivity,
    type: :group,
    description: "Expired activities settings",
    children: [
      %{
        key: :enabled,
        type: :boolean,
        description: "Enables expired activities addition & deletion"
      },
      %{
        key: :min_lifetime,
        type: :integer,
        description: "Minimum lifetime for ephemeral activity (in seconds)",
        suggestions: [600]
      }
    ]
  },
  %{
    group: :pleroma,
    label: "Pleroma Authenticator",
    type: :group,
    description: "Authenticator",
    children: [
      %{
        key: Pleroma.Web.Auth.Authenticator,
        type: :module,
        suggestions: [Pleroma.Web.Auth.PleromaAuthenticator, Pleroma.Web.Auth.LDAPAuthenticator]
      }
    ]
  },
  %{
    group: :pleroma,
    key: :ldap,
    label: "LDAP",
    type: :group,
    description:
      "Use LDAP for user authentication. When a user logs in to the Pleroma instance, the name and password" <>
        " will be verified by trying to authenticate (bind) to a LDAP server." <>
        " If a user exists in the LDAP directory but there is no account with the same name yet on the" <>
        " Pleroma instance then a new Pleroma account will be created with the same name as the LDAP user name.",
    children: [
      %{
        key: :enabled,
        type: :boolean,
        description: "Enables LDAP authentication"
      },
      %{
        key: :host,
        type: :string,
        description: "LDAP server hostname",
        suggestions: ["localhosts"]
      },
      %{
        key: :port,
        type: :integer,
        description: "LDAP port, e.g. 389 or 636",
        suggestions: [389, 636]
      },
      %{
        key: :ssl,
        label: "SSL",
        type: :boolean,
        description: "Enable to use SSL, usually implies the port 636"
      },
      %{
        key: :sslopts,
        label: "SSL options",
        type: :keyword,
        description: "Additional SSL options",
        suggestions: [cacertfile: "path/to/file/with/PEM/cacerts", verify: :verify_peer],
        children: [
          %{
            key: :cacertfile,
            type: :string,
            description: "Path to file with PEM encoded cacerts",
            suggestions: ["path/to/file/with/PEM/cacerts"]
          },
          %{
            key: :verify,
            type: :atom,
            description: "Type of cert verification",
            suggestions: [:verify_peer]
          }
        ]
      },
      %{
        key: :tls,
        label: "TLS",
        type: :boolean,
        description: "Enable to use STARTTLS, usually implies the port 389"
      },
      %{
        key: :tlsopts,
        label: "TLS options",
        type: :keyword,
        description: "Additional TLS options",
        suggestions: [cacertfile: "path/to/file/with/PEM/cacerts", verify: :verify_peer],
        children: [
          %{
            key: :cacertfile,
            type: :string,
            description: "Path to file with PEM encoded cacerts",
            suggestions: ["path/to/file/with/PEM/cacerts"]
          },
          %{
            key: :verify,
            type: :atom,
            description: "Type of cert verification",
            suggestions: [:verify_peer]
          }
        ]
      },
      %{
        key: :base,
        type: :string,
        description: "LDAP base, e.g. \"dc=example,dc=com\"",
        suggestions: ["dc=example,dc=com"]
      },
      %{
        key: :uid,
        label: "UID",
        type: :string,
        description:
          "LDAP attribute name to authenticate the user, e.g. when \"cn\", the filter will be \"cn=username,base\"",
        suggestions: ["cn"]
      }
    ]
  },
  %{
    group: :pleroma,
    key: :auth,
    type: :group,
    description: "Authentication / authorization settings",
    children: [
      %{
        key: :enforce_oauth_admin_scope_usage,
        label: "Enforce OAuth admin scope usage",
        type: :boolean,
        description:
          "OAuth admin scope requirement toggle. " <>
            "If enabled, admin actions explicitly demand admin OAuth scope(s) presence in OAuth token " <>
            "(client app must support admin scopes). If disabled and token doesn't have admin scope(s), " <>
            "`is_admin` user flag grants access to admin-specific actions."
      },
      %{
        key: :auth_template,
        type: :string,
        description:
          "Authentication form template. By default it's `show.html` which corresponds to `lib/pleroma/web/templates/o_auth/o_auth/show.html.ee`.",
        suggestions: ["show.html"]
      },
      %{
        key: :oauth_consumer_template,
        label: "OAuth consumer template",
        type: :string,
        description:
          "OAuth consumer mode authentication form template. By default it's `consumer.html` which corresponds to" <>
            " `lib/pleroma/web/templates/o_auth/o_auth/consumer.html.eex`.",
        suggestions: ["consumer.html"]
      },
      %{
        key: :oauth_consumer_strategies,
        label: "OAuth consumer strategies",
        type: {:list, :string},
        description:
          "The list of enabled OAuth consumer strategies. By default it's set by OAUTH_CONSUMER_STRATEGIES environment variable." <>
            " Each entry in this space-delimited string should be of format \"strategy\" or \"strategy:dependency\"" <>
            " (e.g. twitter or keycloak:ueberauth_keycloak_strategy in case dependency is named differently than ueberauth_<strategy>).",
        suggestions: ["twitter", "keycloak:ueberauth_keycloak_strategy"]
      }
    ]
  },
  %{
    group: :pleroma,
    key: :email_notifications,
    type: :group,
    description: "Email notifications settings",
    children: [
      %{
        key: :digest,
        type: :map,
        description:
          "emails of \"what you've missed\" for users who have been inactive for a while",
        suggestions: [
          %{
            active: false,
            schedule: "0 0 * * 0",
            interval: 7,
            inactivity_threshold: 7
          }
        ],
        children: [
          %{
            key: :active,
            label: "Enabled",
            type: :boolean,
            description: "Globally enable or disable digest emails"
          },
          %{
            key: :schedule,
            type: :string,
            description:
              "When to send digest email, in crontab format. \"0 0 0\" is the default, meaning \"once a week at midnight on Sunday morning\".",
            suggestions: ["0 0 * * 0"]
          },
          %{
            key: :interval,
            type: :integer,
            description: "Minimum interval between digest emails to one user",
            suggestions: [7]
          },
          %{
            key: :inactivity_threshold,
            type: :integer,
            description: "Minimum user inactivity threshold",
            suggestions: [7]
          }
        ]
      }
    ]
  },
  %{
    group: :pleroma,
    key: Pleroma.Emails.UserEmail,
    type: :group,
    description: "Email template settings",
    children: [
      %{
        key: :logo,
        type: {:string, :image},
        description: "A path to a custom logo. Set it to `nil` to use the default Pleroma logo.",
        suggestions: ["some/path/logo.png"]
      },
      %{
        key: :styling,
        type: :map,
        description: "A map with color settings for email templates.",
        suggestions: [
          %{
            link_color: "#d8a070",
            background_color: "#2C3645",
            content_background_color: "#1B2635",
            header_color: "#d8a070",
            text_color: "#b9b9ba",
            text_muted_color: "#b9b9ba"
          }
        ],
        children: [
          %{
            key: :link_color,
            type: :string,
            suggestions: ["#d8a070"]
          },
          %{
            key: :background_color,
            type: :string,
            suggestions: ["#2C3645"]
          },
          %{
            key: :content_background_color,
            type: :string,
            suggestions: ["#1B2635"]
          },
          %{
            key: :header_color,
            type: :string,
            suggestions: ["#d8a070"]
          },
          %{
            key: :text_color,
            type: :string,
            suggestions: ["#b9b9ba"]
          },
          %{
            key: :text_muted_color,
            type: :string,
            suggestions: ["#b9b9ba"]
          }
        ]
      }
    ]
  },
  %{
    group: :pleroma,
    key: Pleroma.Emails.NewUsersDigestEmail,
    type: :group,
    description: "New users admin email digest",
    children: [
      %{
        key: :enabled,
        type: :boolean,
        description: "Enables new users admin digest email when `true`"
      }
    ]
  },
  %{
    group: :pleroma,
    key: :oauth2,
    label: "OAuth2",
    type: :group,
    description: "Configure OAuth 2 provider capabilities",
    children: [
      %{
        key: :token_expires_in,
        type: :integer,
        description: "The lifetime in seconds of the access token",
        suggestions: [2_592_000]
      },
      %{
        key: :issue_new_refresh_token,
        type: :boolean,
        description:
          "Keeps old refresh token or generate new refresh token when to obtain an access token"
      },
      %{
        key: :clean_expired_tokens,
        type: :boolean,
        description: "Enable a background job to clean expired OAuth tokens. Default: disabled."
      }
    ]
  },
  %{
    group: :pleroma,
    key: :emoji,
    type: :group,
    children: [
      %{
        key: :shortcode_globs,
        type: {:list, :string},
        description: "Location of custom emoji files. * can be used as a wildcard.",
        suggestions: ["/emoji/custom/**/*.png"]
      },
      %{
        key: :pack_extensions,
        type: {:list, :string},
        description:
          "A list of file extensions for emojis, when no emoji.txt for a pack is present",
        suggestions: [".png", ".gif"]
      },
      %{
        key: :groups,
        type: {:keyword, {:list, :string}},
        description:
          "Emojis are ordered in groups (tags). This is an array of key-value pairs where the key is the group name" <>
            " and the value is the location or array of locations. * can be used as a wildcard.",
        suggestions: [
          Custom: ["/emoji/*.png", "/emoji/**/*.png"]
        ]
      },
      %{
        key: :default_manifest,
        type: :string,
        description:
          "Location of the JSON-manifest. This manifest contains information about the emoji-packs you can download." <>
            " Currently only one manifest can be added (no arrays).",
        suggestions: ["https://git.pleroma.social/pleroma/emoji-index/raw/master/index.json"]
      },
      %{
        key: :shared_pack_cache_seconds_per_file,
        label: "Shared pack cache s/file",
        type: :integer,
        descpiption:
          "When an emoji pack is shared, the archive is created and cached in memory" <>
            " for this amount of seconds multiplied by the number of files.",
        suggestions: [60]
      }
    ]
  },
  %{
    group: :pleroma,
    key: :rate_limit,
    type: :group,
    description:
      "Rate limit settings. This is an advanced feature enabled only for :authentication by default.",
    children: [
      %{
        key: :search,
        type: [:tuple, {:list, :tuple}],
        description: "For the search requests (account & status search etc.)",
        suggestions: [{1000, 10}, [{10_000, 10}, {10_000, 50}]]
      },
      %{
        key: :timeline,
        type: [:tuple, {:list, :tuple}],
        description: "For requests to timelines (each timeline has it's own limiter)",
        suggestions: [{1000, 10}, [{10_000, 10}, {10_000, 50}]]
      },
      %{
        key: :app_account_creation,
        type: [:tuple, {:list, :tuple}],
        description: "For registering user accounts from the same IP address",
        suggestions: [{1000, 10}, [{10_000, 10}, {10_000, 50}]]
      },
      %{
        key: :relations_actions,
        type: [:tuple, {:list, :tuple}],
        description: "For actions on relationships with all users (follow, unfollow)",
        suggestions: [{1000, 10}, [{10_000, 10}, {10_000, 50}]]
      },
      %{
        key: :relation_id_action,
        label: "Relation ID action",
        type: [:tuple, {:list, :tuple}],
        description: "For actions on relation with a specific user (follow, unfollow)",
        suggestions: [{1000, 10}, [{10_000, 10}, {10_000, 50}]]
      },
      %{
        key: :statuses_actions,
        type: [:tuple, {:list, :tuple}],
        description:
          "For create / delete / fav / unfav / reblog / unreblog actions on any statuses",
        suggestions: [{1000, 10}, [{10_000, 10}, {10_000, 50}]]
      },
      %{
        key: :status_id_action,
        label: "Status ID action",
        type: [:tuple, {:list, :tuple}],
        description:
          "For fav / unfav or reblog / unreblog actions on the same status by the same user",
        suggestions: [{1000, 10}, [{10_000, 10}, {10_000, 50}]]
      },
      %{
        key: :authentication,
        type: [:tuple, {:list, :tuple}],
        description: "For authentication create / password check / user existence check requests",
        suggestions: [{60_000, 15}]
      }
    ]
  },
  %{
    group: :esshd,
    label: "ESSHD",
    type: :group,
    description:
      "Before enabling this you must add :esshd to mix.exs as one of the extra_applications " <>
        "and generate host keys in your priv dir with ssh-keygen -m PEM -N \"\" -b 2048 -t rsa -f ssh_host_rsa_key",
    children: [
      %{
        key: :enabled,
        type: :boolean,
        description: "Enables SSH"
      },
      %{
        key: :priv_dir,
        type: :string,
        description: "Dir with SSH keys",
        suggestions: ["/some/path/ssh_keys"]
      },
      %{
        key: :handler,
        type: :string,
        description: "Handler module",
        suggestions: ["Pleroma.BBS.Handler"]
      },
      %{
        key: :port,
        type: :integer,
        description: "Port to connect",
        suggestions: [10_022]
      },
      %{
        key: :password_authenticator,
        type: :string,
        description: "Authenticator module",
        suggestions: ["Pleroma.BBS.Authenticator"]
      }
    ]
  },
  %{
    group: :mime,
    label: "Mime Types",
    type: :group,
    description: "Mime Types settings",
    children: [
      %{
        key: :types,
        type: :map,
        suggestions: [
          %{
            "application/xml" => ["xml"],
            "application/xrd+xml" => ["xrd+xml"],
            "application/jrd+json" => ["jrd+json"],
            "application/activity+json" => ["activity+json"],
            "application/ld+json" => ["activity+json"]
          }
        ],
        children: [
          %{
            key: "application/xml",
            type: {:list, :string},
            suggestions: ["xml"]
          },
          %{
            key: "application/xrd+xml",
            type: {:list, :string},
            suggestions: ["xrd+xml"]
          },
          %{
            key: "application/jrd+json",
            type: {:list, :string},
            suggestions: ["jrd+json"]
          },
          %{
            key: "application/activity+json",
            type: {:list, :string},
            suggestions: ["activity+json"]
          },
          %{
            key: "application/ld+json",
            type: {:list, :string},
            suggestions: ["activity+json"]
          }
        ]
      }
    ]
  },
  %{
    group: :pleroma,
    key: :shout,
    type: :group,
    description: "Pleroma shout settings",
    children: [
      %{
        key: :enabled,
        type: :boolean,
        description: "Enables the backend Shoutbox chat feature."
      },
      %{
        key: :limit,
        type: :integer,
        description: "Shout message character limit.",
        suggestions: [
          5_000
        ]
      }
    ]
  },
  %{
    group: :pleroma,
    key: :http,
    label: "HTTP",
    type: :group,
    description: "HTTP settings",
    children: [
      %{
        key: :proxy_url,
        label: "Proxy URL",
        type: [:string, :tuple],
        description: "Proxy URL",
        suggestions: ["localhost:9020", {:socks5, :localhost, 3090}]
      },
      %{
        key: :send_user_agent,
        type: :boolean
      },
      %{
        key: :user_agent,
        type: [:string, :atom],
        description:
          "What user agent to use. Must be a string or an atom `:default`. Default value is `:default`.",
        suggestions: ["Pleroma", :default]
      },
      %{
        key: :adapter,
        type: :keyword,
        description: "Adapter specific options",
        suggestions: [],
        children: [
          %{
            key: :ssl_options,
            type: :keyword,
            label: "SSL Options",
            description: "SSL options for HTTP adapter",
            children: [
              %{
                key: :versions,
                type: {:list, :atom},
                description: "List of TLS version to use",
                suggestions: [:tlsv1, ":tlsv1.1", ":tlsv1.2"]
              }
            ]
          }
        ]
      }
    ]
  },
  %{
    group: :pleroma,
    key: :markup,
    label: "Markup Settings",
    type: :group,
    children: [
      %{
        key: :allow_inline_images,
        type: :boolean
      },
      %{
        key: :allow_headings,
        type: :boolean
      },
      %{
        key: :allow_tables,
        type: :boolean
      },
      %{
        key: :allow_fonts,
        type: :boolean
      },
      %{
        key: :scrub_policy,
        type: {:list, :module},
        description:
          "Module names are shortened (removed leading `Pleroma.HTML.` part), but on adding custom module you need to use full name.",
        suggestions: [Pleroma.HTML.Transform.MediaProxy, Pleroma.HTML.Scrubber.Default]
      }
    ]
  },
  %{
    group: :pleroma,
    key: :user,
    type: :group,
    children: [
      %{
        key: :deny_follow_blocked,
        type: :boolean
      }
    ]
  },
  %{
    group: :pleroma,
    key: Pleroma.User,
    type: :group,
    children: [
      %{
        key: :restricted_nicknames,
        type: {:list, :string},
        description: "List of nicknames users may not register with.",
        suggestions: [
          ".well-known",
          "~",
          "about",
          "activities",
          "api",
          "auth",
          "check_password",
          "dev",
          "friend-requests",
          "inbox",
          "internal",
          "main",
          "media",
          "nodeinfo",
          "notice",
          "oauth",
          "objects",
          "ostatus_subscribe",
          "pleroma",
          "proxy",
          "push",
          "registration",
          "relay",
          "settings",
          "status",
          "tag",
          "user-search",
          "user_exists",
          "users",
          "web"
        ]
      },
      %{
        key: :email_blacklist,
        type: {:list, :string},
        description: "List of email domains users may not register with.",
        suggestions: ["mailinator.com", "maildrop.cc"]
      }
    ]
  },
  %{
    group: :cors_plug,
    label: "CORS plug config",
    type: :group,
    children: [
      %{
        key: :max_age,
        type: :integer,
        suggestions: [86_400]
      },
      %{
        key: :methods,
        type: {:list, :string},
        suggestions: ["POST", "PUT", "DELETE", "GET", "PATCH", "OPTIONS"]
      },
      %{
        key: :expose,
        type: {:list, :string},
        suggestions: [
          "Link",
          "X-RateLimit-Reset",
          "X-RateLimit-Limit",
          "X-RateLimit-Remaining",
          "X-Request-Id",
          "Idempotency-Key"
        ]
      },
      %{
        key: :credentials,
        type: :boolean
      },
      %{
        key: :headers,
        type: {:list, :string},
        suggestions: ["Authorization", "Content-Type", "Idempotency-Key"]
      }
    ]
  },
  %{
    group: :pleroma,
    key: Pleroma.Web.Plugs.RemoteIp,
    type: :group,
    description: """
    `Pleroma.Web.Plugs.RemoteIp` is a shim to call [`RemoteIp`](https://git.pleroma.social/pleroma/remote_ip) but with runtime configuration.
    **If your instance is not behind at least one reverse proxy, you should not enable this plug.**
    """,
    children: [
      %{
        key: :enabled,
        type: :boolean,
        description: "Enable/disable the plug. Default: disabled."
      },
      %{
        key: :headers,
        type: {:list, :string},
        description: """
          A list of strings naming the HTTP headers to use when deriving the true client IP. Default: `["x-forwarded-for"]`.
        """
      },
      %{
        key: :proxies,
        type: {:list, :string},
        description:
          "A list of upstream proxy IP subnets in CIDR notation from which we will parse the content of `headers`. Defaults to `[]`. IPv4 entries without a bitmask will be assumed to be /32 and IPv6 /128."
      },
      %{
        key: :reserved,
        type: {:list, :string},
        description: """
          A list of reserved IP subnets in CIDR notation which should be ignored if found in `headers`. Defaults to `["127.0.0.0/8", "::1/128", "fc00::/7", "10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]`
        """
      }
    ]
  },
  %{
    group: :pleroma,
    key: :web_cache_ttl,
    label: "Web cache TTL",
    type: :group,
    description:
      "The expiration time for the web responses cache. Values should be in milliseconds or `nil` to disable expiration.",
    children: [
      %{
        key: :activity_pub,
        type: :integer,
        description:
          "Activity pub routes (except question activities). Default: `nil` (no expiration).",
        suggestions: [nil]
      },
      %{
        key: :activity_pub_question,
        type: :integer,
        description: "Activity pub routes (question activities). Default: `30_000` (30 seconds).",
        suggestions: [30_000]
      }
    ]
  },
  %{
    group: :pleroma,
    key: :static_fe,
    label: "Static FE",
    type: :group,
    description:
      "Render profiles and posts using server-generated HTML that is viewable without using JavaScript",
    children: [
      %{
        key: :enabled,
        type: :boolean,
        description: "Enables the rendering of static HTML. Default: disabled."
      }
    ]
  },
  %{
    group: :pleroma,
    key: :feed,
    type: :group,
    description: "Configure feed rendering",
    children: [
      %{
        key: :post_title,
        type: :map,
        description: "Configure title rendering",
        children: [
          %{
            key: :max_length,
            type: :integer,
            description: "Maximum number of characters before truncating title",
            suggestions: [100]
          },
          %{
            key: :omission,
            type: :string,
            description: "Replacement which will be used after truncating string",
            suggestions: ["..."]
          }
        ]
      }
    ]
  },
  %{
    group: :pleroma,
    key: :mrf_follow_bot,
    tab: :mrf,
    related_policy: "Pleroma.Web.ActivityPub.MRF.FollowBotPolicy",
    label: "MRF FollowBot Policy",
    type: :group,
    description: "Automatically follows newly discovered accounts.",
    children: [
      %{
        key: :follower_nickname,
        type: :string,
        description: "The name of the bot account to use for following newly discovered users.",
        suggestions: ["followbot"]
      }
    ]
  },
  %{
    group: :pleroma,
    key: :modules,
    type: :group,
    description: "Custom Runtime Modules",
    children: [
      %{
        key: :runtime_dir,
        type: :string,
        description: "A path to custom Elixir modules (such as MRF policies)."
      }
    ]
  },
  %{
    group: :pleroma,
    key: :streamer,
    type: :group,
    description: "Settings for notifications streamer",
    children: [
      %{
        key: :workers,
        type: :integer,
        description: "Number of workers to send notifications",
        suggestions: [3]
      },
      %{
        key: :overflow_workers,
        type: :integer,
        description: "Maximum number of workers created if pool is empty",
        suggestions: [2]
      }
    ]
  },
  %{
    group: :pleroma,
    key: :connections_pool,
    type: :group,
    description: "Advanced settings for `Gun` connections pool",
    children: [
      %{
        key: :connection_acquisition_wait,
        type: :integer,
        description:
          "Timeout to acquire a connection from pool. The total max time is this value multiplied by the number of retries. Default: 250ms.",
        suggestions: [250]
      },
      %{
        key: :connection_acquisition_retries,
        type: :integer,
        description:
          "Number of attempts to acquire the connection from the pool if it is overloaded. Default: 5",
        suggestions: [5]
      },
      %{
        key: :max_connections,
        type: :integer,
        description: "Maximum number of connections in the pool. Default: 250 connections.",
        suggestions: [250]
      },
      %{
        key: :connect_timeout,
        type: :integer,
        description: "Timeout while `gun` will wait until connection is up. Default: 5000ms.",
        suggestions: [5000]
      },
      %{
        key: :reclaim_multiplier,
        type: :integer,
        description:
          "Multiplier for the number of idle connection to be reclaimed if the pool is full. For example if the pool maxes out at 250 connections and this setting is set to 0.3, the pool will reclaim at most 75 idle connections if it's overloaded. Default: 0.1",
        suggestions: [0.1]
      }
    ]
  },
  %{
    group: :pleroma,
    key: :pools,
    type: :group,
    description: "Advanced settings for `Gun` workers pools",
    children:
      Enum.map([:federation, :media, :upload, :default], fn pool_name ->
        %{
          key: pool_name,
          type: :keyword,
          description: "Settings for #{pool_name} pool.",
          children: [
            %{
              key: :size,
              type: :integer,
              description: "Maximum number of concurrent requests in the pool.",
              suggestions: [50]
            },
            %{
              key: :max_waiting,
              type: :integer,
              description:
                "Maximum number of requests waiting for other requests to finish. After this number is reached, the pool will start returning errrors when a new request is made",
              suggestions: [10]
            },
            %{
              key: :recv_timeout,
              type: :integer,
              description: "Timeout for the pool while gun will wait for response",
              suggestions: [10_000]
            }
          ]
        }
      end)
  },
  %{
    group: :pleroma,
    key: :hackney_pools,
    type: :group,
    description: "Advanced settings for `Hackney` connections pools",
    children: [
      %{
        key: :federation,
        type: :keyword,
        description: "Settings for federation pool.",
        children: [
          %{
            key: :max_connections,
            type: :integer,
            description: "Number workers in the pool.",
            suggestions: [50]
          },
          %{
            key: :timeout,
            type: :integer,
            description: "Timeout while `hackney` will wait for response.",
            suggestions: [150_000]
          }
        ]
      },
      %{
        key: :media,
        type: :keyword,
        description: "Settings for media pool.",
        children: [
          %{
            key: :max_connections,
            type: :integer,
            description: "Number workers in the pool.",
            suggestions: [50]
          },
          %{
            key: :timeout,
            type: :integer,
            description: "Timeout while `hackney` will wait for response.",
            suggestions: [150_000]
          }
        ]
      },
      %{
        key: :upload,
        type: :keyword,
        description: "Settings for upload pool.",
        children: [
          %{
            key: :max_connections,
            type: :integer,
            description: "Number workers in the pool.",
            suggestions: [25]
          },
          %{
            key: :timeout,
            type: :integer,
            description: "Timeout while `hackney` will wait for response.",
            suggestions: [300_000]
          }
        ]
      }
    ]
  },
  %{
    group: :pleroma,
    key: :restrict_unauthenticated,
    label: "Restrict Unauthenticated",
    type: :group,
    description:
      "Disallow viewing timelines, user profiles and statuses for unauthenticated users.",
    children: [
      %{
        key: :timelines,
        type: :map,
        description: "Settings for public and federated timelines.",
        children: [
          %{
            key: :local,
            type: :boolean,
            description: "Disallow view public timeline."
          },
          %{
            key: :federated,
            type: :boolean,
            description: "Disallow view federated timeline."
          }
        ]
      },
      %{
        key: :profiles,
        type: :map,
        description: "Settings for user profiles.",
        children: [
          %{
            key: :local,
            type: :boolean,
            description: "Disallow view local user profiles."
          },
          %{
            key: :remote,
            type: :boolean,
            description: "Disallow view remote user profiles."
          }
        ]
      },
      %{
        key: :activities,
        type: :map,
        description: "Settings for statuses.",
        children: [
          %{
            key: :local,
            type: :boolean,
            description: "Disallow view local statuses."
          },
          %{
            key: :remote,
            type: :boolean,
            description: "Disallow view remote statuses."
          }
        ]
      }
    ]
  },
  %{
    group: :pleroma,
    key: Pleroma.Web.ApiSpec.CastAndValidate,
    type: :group,
    children: [
      %{
        key: :strict,
        type: :boolean,
        description:
          "Enables strict input validation (useful in development, not recommended in production)"
      }
    ]
  },
  %{
    group: :pleroma,
    key: :instances_favicons,
    type: :group,
    description: "Control favicons for instances",
    children: [
      %{
        key: :enabled,
        type: :boolean,
        description: "Allow/disallow displaying and getting instances favicons"
      }
    ]
  },
  %{
    group: :ex_aws,
    key: :s3,
    type: :group,
    descriptions: "S3 service related settings",
    children: [
      %{
        key: :access_key_id,
        type: :string,
        description: "S3 access key ID",
        suggestions: ["AKIAQ8UKHTGIYN7DMWWJ"]
      },
      %{
        key: :secret_access_key,
        type: :string,
        description: "Secret access key",
        suggestions: ["JFGt+fgH1UQ7vLUQjpW+WvjTdV/UNzVxcwn7DkaeFKtBS5LvoXvIiME4NQBsT6ZZ"]
      },
      %{
        key: :host,
        type: :string,
        description: "S3 host",
        suggestions: ["s3.eu-central-1.amazonaws.com"]
      },
      %{
        key: :region,
        type: :string,
        description: "S3 region (for AWS)",
        suggestions: ["us-east-1"]
      }
    ]
  },
  %{
    group: :pleroma,
    key: :frontends,
    type: :group,
    description: "Installed frontends management",
    children: [
      %{
        key: :primary,
        type: :map,
        description: "Primary frontend, the one that is served for all pages by default",
        children: installed_frontend_options
      },
      %{
        key: :admin,
        type: :map,
        description: "Admin frontend",
        children: installed_frontend_options
      },
      %{
        key: :available,
        type: :map,
        description:
          "A map containing available frontends and parameters for their installation.",
        children: frontend_options
      }
    ]
  },
  %{
    group: :pleroma,
    key: Pleroma.Web.Preload,
    type: :group,
    description: "Preload-related settings",
    children: [
      %{
        key: :providers,
        type: {:list, :module},
        description: "List of preload providers to enable",
        suggestions: [
          Pleroma.Web.Preload.Providers.Instance,
          Pleroma.Web.Preload.Providers.User,
          Pleroma.Web.Preload.Providers.Timelines,
          Pleroma.Web.Preload.Providers.StatusNet
        ]
      }
    ]
  },
  %{
    group: :pleroma,
    key: :majic_pool,
    type: :group,
    description: "Majic/libmagic configuration",
    children: [
      %{
        key: :size,
        type: :integer,
        description: "Number of majic workers to start.",
        suggestions: [2]
      }
    ]
  },
  %{
    group: :pleroma,
    key: Pleroma.User.Backup,
    type: :group,
    description: "Account Backup",
    children: [
      %{
        key: :purge_after_days,
        type: :integer,
        description: "Remove backup achives after N days",
        suggestions: [30]
      },
      %{
        key: :limit_days,
        type: :integer,
        description: "Limit user to export not more often than once per N days",
        suggestions: [7]
      }
    ]
  },
  %{
    group: :prometheus,
    key: Pleroma.Web.Endpoint.MetricsExporter,
    type: :group,
    description: "Prometheus app metrics endpoint configuration",
    children: [
      %{
        key: :enabled,
        type: :boolean,
        description: "[Pleroma extension] Enables app metrics endpoint."
      },
      %{
        key: :ip_whitelist,
        label: "IP Whitelist",
        type: [{:list, :string}, {:list, :charlist}, {:list, :tuple}],
        description: "Restrict access of app metrics endpoint to the specified IP addresses."
      },
      %{
        key: :auth,
        type: [:boolean, :tuple],
        description: "Enables HTTP Basic Auth for app metrics endpoint.",
        suggestion: [false, {:basic, "myusername", "mypassword"}]
      },
      %{
        key: :path,
        type: :string,
        description: "App metrics endpoint URI path.",
        suggestions: ["/api/pleroma/app_metrics"]
      },
      %{
        key: :format,
        type: :atom,
        description: "App metrics endpoint output format.",
        suggestions: [:text, :protobuf]
      }
    ]
  },
  %{
    group: :pleroma,
    key: ConcurrentLimiter,
    type: :group,
    description: "Limits configuration for background tasks.",
    children: [
      %{
        key: Pleroma.Web.RichMedia.Helpers,
        type: :keyword,
        description: "Concurrent limits configuration for getting RichMedia for activities.",
        suggestions: [max_running: 5, max_waiting: 5],
        children: [
          %{
            key: :max_running,
            type: :integer,
            description: "Max running concurrently jobs.",
            suggestion: [5]
          },
          %{
            key: :max_waiting,
            type: :integer,
            description: "Max waiting jobs.",
            suggestion: [5]
          }
        ]
      },
      %{
        key: Pleroma.Web.ActivityPub.MRF.MediaProxyWarmingPolicy,
        type: :keyword,
        description: "Concurrent limits configuration for MediaProxyWarmingPolicy.",
        suggestions: [max_running: 5, max_waiting: 5],
        children: [
          %{
            key: :max_running,
            type: :integer,
            description: "Max running concurrently jobs.",
            suggestion: [5]
          },
          %{
            key: :max_waiting,
            type: :integer,
            description: "Max waiting jobs.",
            suggestion: [5]
          }
        ]
      }
    ]
  }
]
