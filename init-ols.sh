#!/bin/sh

(echo | cat << ===
{
  "\$schema": "https://raw.githubusercontent.com/DanielGavin/ols/master/misc/ols.schema.json",
  "enable_semantic_tokens": false,
  "enable_document_symbols": true,
  "enable_hover": true,
  "enable_snippets": true,
  "profile": "default",
	"profiles": [
		{ "name": "default", "checker_path": ["src"] },
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
