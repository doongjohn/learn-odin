#!/bin/sh

(echo | cat << ___
{
  "\$schema": "https://raw.githubusercontent.com/DanielGavin/ols/master/misc/ols.schema.json",
  "collections": [
    { "name": "core", "path": "${HOME}/odin/core" },
    { "name": "vendor", "path": "${HOME}/odin/vendor" },
  ],
  "enable_hover": true,
  "enable_snippets": true,
  "enable_semantic_tokens": true,
  "enable_document_symbols": true
}
___
) > ols.json

(echo | cat << ___
{
  "\$schema": "https://raw.githubusercontent.com/DanielGavin/ols/master/misc/odinfmt.schema.json",
  "tabs": true,
  "tabs_width": 4,
  "character_width": 100
}
___
) > odinfmt.json
