int choose(bool condition, int left, int right) {
	int result;
	if (condition) {
		result = left + 1;
	} else {
		result = right - 1;
	}
	return result;
}
