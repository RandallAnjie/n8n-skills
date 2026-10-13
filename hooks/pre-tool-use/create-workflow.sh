#!/usr/bin/env bash
# Fires before create_workflow_from_code. New workflow means readability
# and subworkflow-reuse decisions need to happen before code lands.
exec "$(dirname "$0")/_emit.sh" "lifecycle-subworkflows" \
"Before creating: if the user asked for a PoC/demo/vibe/prototype, invoke n8n-poc-quickstart. Otherwise invoke n8n-workflow-lifecycle-official (node groups, stickies, naming) and n8n-subworkflows-official (search by tag before duplicating) via the Skill tool."
