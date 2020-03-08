# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

import EctoEnum

defenum(UserRelationshipTypeEnum,
  block: 1,
  mute: 2,
  reblog_mute: 3,
  notification_mute: 4,
  inverse_subscription: 5
)
