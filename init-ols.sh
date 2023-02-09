#!/bin/sh
(echo | cat << ___
{
  "collections": [
    { "name": "core", "path": "${HOME}/odin/core" },
    { "name": "vendor", "path": "${HOME}/odin/vendor" },
  ],
  "enable_semantic_tokens": true,
  "enable_document_symbols": true,
  "enable_hover": true,
  "enable_format": true,
  "enable_snippets": true,
  "formatter": {
    "tabs": true,
    "characters": 100
  }
}
___
) > ols.json
