class_name Apple
extends RefCounted
## Game Center and StoreKit, reached by name instead of by type.
##
## The Apple plugins are GDExtensions with libraries for iOS, macOS and a Linux
## stub — and nothing for Android. On a platform with no library the classes are
## never registered, so a script that so much as *names* `GKPlayer` in a type
## hint fails to parse, and every script that depends on it fails behind it. On
## Android that was five scripts and a black screen.
##
## So the Apple-facing scripts hold these objects untyped and reach the classes
## through ClassDB: construction, static calls and constants all go by string,
## which parses everywhere and simply finds nothing where there is nothing. The
## `available()` checks each script already had are what keep these from being
## called on a platform without the class.


## Whether the class is registered in this build at all.
static func has(cls: String) -> bool:
	return ClassDB.class_exists(cls)


## `cls.new()`, or null where the class is missing or refuses construction —
## the Linux stub registers every class and then declines to build any of them.
static func make(cls: String) -> Object:
	if not ClassDB.can_instantiate(cls):
		return null
	return ClassDB.instantiate(cls)


## `cls.method(args...)` for a static method.
static func call_static(cls: String, method: String, args: Array = []) -> Variant:
	return ClassDB.callv("class_call_static", [cls, method] + args)


## `cls.NAME` for an integer or enum constant. Read from the plugin rather than
## copied here, so a plugin update that renumbers an enum cannot desync us.
static func k(cls: String, constant: String) -> int:
	return ClassDB.class_get_integer_constant(cls, constant)


## `value is cls`, without naming the class.
static func is_a(value: Variant, cls: String) -> bool:
	return value is Object and value != null and (value as Object).is_class(cls)
