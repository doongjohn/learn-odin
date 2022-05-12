#!/bin/sh
(echo | cat << ___
{
  "collections": [
    { "name": "core", "path": "${HOME}/odin/core" },
    { "name": "vendor", "path": "${HOME}/odin/vendor" },
    { "name": "shared", "path": "${PWD}/src" }
  ],
  "thread_pool_count": 4,
  "enable_semantic_tokens": false,
  "enable_document_symbols": true,
  "enable_hover": true,
  "enable_format": true,
  "enable_snippets": true,
  "formatter": {
    "tabs": true,
    "characters": 90
  }
}
___
) > ols.json
