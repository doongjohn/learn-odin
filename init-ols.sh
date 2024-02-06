#!/bin/sh

ODIN_HOME="$HOME/odin"

(echo | cat << ===
{
  "\$schema": "https://raw.githubusercontent.com/DanielGavin/ols/master/misc/ols.schema.json",
  "enable_hover": true,
  "enable_snippets": true,
  "enable_semantic_tokens": true,
  "enable_document_symbols": true,
  "enable_inlay_hints": true,
  "collections": [
    { "name": "base", "path": "$ODIN_HOME/base" },
    { "name": "core", "path": "$ODIN_HOME/core" },
    { "name": "vendor", "path": "$ODIN_HOME/vendor" }
  ]
}
===
) > ols.json

(echo | cat << ===
{
  "\$schema": "https://raw.githubusercontent.com/DanielGavin/ols/master/misc/odinfmt.schema.json",
  "character_width": 100,
  "tabs": true,
  "tabs_width": 4
}
===
) > odinfmt.json
