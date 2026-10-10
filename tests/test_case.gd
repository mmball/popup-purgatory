class_name TestCase
extends RefCounted
## Minimal assertion helper. Each test_* method runs with a fresh failure list.

var failures: Array[String] = []


func assert_true(cond: bool, msg: String = "expected true") -> void:
	if not cond:
		failures.append(msg)


func assert_false(cond: bool, msg: String = "expected false") -> void:
	if cond:
		failures.append(msg)


func assert_eq(a, b, msg: String = "") -> void:
	if a != b:
		failures.append("%s expected %s, got %s" % [msg, str(b), str(a)])


func assert_ne(a, b, msg: String = "") -> void:
	if a == b:
		failures.append("%s expected something other than %s" % [msg, str(b)])


func assert_gt(a, b, msg: String = "") -> void:
	if not (a > b):
		failures.append("%s expected %s > %s" % [msg, str(a), str(b)])


func assert_ge(a, b, msg: String = "") -> void:
	if not (a >= b):
		failures.append("%s expected %s >= %s" % [msg, str(a), str(b)])


func assert_lt(a, b, msg: String = "") -> void:
	if not (a < b):
		failures.append("%s expected %s < %s" % [msg, str(a), str(b)])


func assert_le(a, b, msg: String = "") -> void:
	if not (a <= b):
		failures.append("%s expected %s <= %s" % [msg, str(a), str(b)])


func assert_near(a: float, b: float, eps: float = 0.001, msg: String = "") -> void:
	if absf(a - b) > eps:
		failures.append("%s expected %s ~= %s" % [msg, str(a), str(b)])
