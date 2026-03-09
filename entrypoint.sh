#!/bin/sh
# Set umask so directories and files created during sync are group-writable.
# This allows other containers sharing the vault (e.g. AI agents) to write
# to directories created by obsidian-headless, provided they run with gid 2500.
umask 002
exec ob "$@"
