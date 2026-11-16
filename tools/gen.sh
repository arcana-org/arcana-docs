#!/bin/sh
#
# The chapters made from Arcana's own tree, at every build of the book,
# never committed: the RESTCONF paths from share/yang (Arcana's
# docs/restconf-modules.py), the deprecated /api from docs/openapi.yaml,
# the programs' manual pages, and the agent's protocol from
# share/arcana/arcana.yaml.
# Arcana is ./arcana: the workflow's checkout, or a link to one.
#
#	tools/gen.sh && mdbook build

set -eu

top=$(cd "$(dirname "$0")/.." && pwd)
a="$top/arcana"
out="$top/src/reference"
[ -d "$a/share/arcana" ] || { echo "gen.sh: no Arcana at $a" >&2; exit 1; }
mkdir -p "$out"

# /api: its OpenAPI document where an Arcana has one; since console
# 0.410.0 /api keeps its plain-HTTP resources alone and has none.
if [ -f "$a/docs/openapi.yaml" ] && [ -f "$a/www/arcana-ui/tools/openapi.awk" ]; then
	awk -f "$a/www/arcana-ui/tools/openapi.awk" "$a/docs/openapi.yaml" |
	    python3 "$top/tools/openapi2md.py" > "$out/api.md"
else
	printf '# /api (deprecated)\n\n%s\n' \
	    'Since console 0.410.0 /api keeps only what is plain HTTP and no YANG module models: sign-in and sessions, health, enrolment, the Suricata pcap files, notifications and the WebSocket. Every other operation is RESTCONF'"'"'s: see [The API: RESTCONF](../automation/restconf.md) and [RESTCONF paths, by module](restconf-paths.md).' \
	    > "$out/api.md"
fi
# RESTCONF's modules and paths, by Arcana's own script (an Arcana before
# it has none: the page says so).
if [ -f "$a/docs/restconf-modules.py" ]; then
	python3 -I "$a/docs/restconf-modules.py" "$a" > "$out/restconf-paths.md"
else
	printf '# RESTCONF paths, by module\n\n%s\n' \
	    'This build of the book read an Arcana without docs/restconf-modules.py; see [The API: RESTCONF](../automation/restconf.md).' \
	    > "$out/restconf-paths.md"
fi
PYTHONPATH="$top/tools" python3 "$top/tools/schema2md.py" \
    "$a/share/arcana/arcana.yaml" > "$out/schema.md"

# A manual page in Markdown, its references to the others made links.
for page in usr.sbin/arcanactl/arcanactl.8 usr.sbin/arcana-agent/arcana-agent.8 \
    usr.sbin/arcana-enrol/arcana-enrol.8 usr.sbin/jailconf/jailconf.8 \
    www/arcana-console/arcana-console.8; do
	name=$(basename "$page" .8)
	# A program in a submodule of its own (jailconf), which the
	# workflow's checkout does not fetch: said, not made.
	if [ ! -f "$a/$page" ]; then
		printf '# %s(8)\n\n%s\n' "$name" \
		    "This build of the book read an Arcana without \`$page\`: the program is in a submodule of its own repository, whose manual page is there." \
		    > "$out/$name.md"
		continue
	fi
	{
		printf '*Generated from `%s` at every build of the book.*\n\n' "$page"
		mandoc -T markdown "$a/$page" |
		    sed -e '1s/^\(.*\)$/# \1/' \
		    -e 's/^# \([A-Z][A-Z ]*\)$/## \1/'
	} > "$out/$name.md"
done
echo "gen.sh: $(ls "$out" | wc -l | tr -d ' ') chapters in src/reference"
