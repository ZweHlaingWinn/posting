#!/usr/bin/env bash
# Build step for Render. Migrations run separately as a pre-deploy command
# (see render.yaml) so a failed migration never replaces the live release.
set -o errexit

bundle install
