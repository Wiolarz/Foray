# Singleton - RES
extends Node

# Cache for keeping resources loaded when they're not present
# At this time a dumb cache without any eviction should be sufficient,
# revisit if it causes memory problems
var _cache := {}


## Load a resource (eg. texture) and manage it here (prefer RES.load() over plain load())
func load(path: String):
	# Even when there's already a resource in _cache, we don't need to fetch them from there -
	# - when the resource is loaded, the load() function returns the same reference
	_cache[path] = load(path)
	return _cache[path]

## Load a resource in background so that it's ready for the next [RES.] load()
func prepare_load(path: String):
	assert(false, "TODO")
