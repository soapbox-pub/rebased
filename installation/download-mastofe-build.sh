#!/bin/sh
# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only
project_id="74"
project_branch="rebase/glitch-soc"
static_dir="instance/static"
# For bundling:
# project_branch="pleroma"
# static_dir="priv/static"

if [[ ! -d "${static_dir}" ]]
then
	echo "Error: ${static_dir} directory is missing, are you sure you are running this script at the root of pleroma’s repository?"
	exit 1
fi

last_modified="$(curl -s -I 'https://git.pleroma.social/api/v4/projects/'${project_id}'/jobs/artifacts/'${project_branch}'/download?job=build' | grep '^Last-Modified:' | cut -d: -f2-)"

echo "branch:${project_branch}"
echo "Last-Modified:${last_modified}"

artifact="mastofe.zip"

if [[ -e mastofe.timestamp ]] && [[ "${last_modified}" != "" ]]
then
	if [[ "$(cat mastofe.timestamp)" == "${last_modified}" ]]
	then
		echo "MastoFE is up-to-date, exiting…"
		exit 0
	fi
fi

curl -c - "https://git.pleroma.social/api/v4/projects/${project_id}/jobs/artifacts/${project_branch}/download?job=build" -o "${artifact}" || exit

# TODO: Update the emoji as well
rm -fr "${static_dir}/sw.js" "${static_dir}/packs" || exit
unzip -q "${artifact}" || exit

cp public/assets/sw.js "${static_dir}/sw.js" || exit
cp -r public/packs "${static_dir}/packs" || exit

echo "${last_modified}" > mastofe.timestamp
rm -fr public
rm -i "${artifact}"
