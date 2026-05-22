class_name FormatHelpers
extends RefCounted

## Static formatting utilities shared across UI scripts.


static func format_cash(amount: float) -> String:
	var value: int = int(amount)
	var negative: bool = value < 0
	if negative:
		value = -value

	var text: String = str(value)
	var result: String = ""
	var count: int = 0
	for i in range(text.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			result = "," + result
		result = text[i] + result
		count += 1

	if negative:
		return "§-" + result
	return "§" + result
