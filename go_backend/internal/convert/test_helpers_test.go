package convert

func stringSlicesEqual(a, b []string) bool {
	if len(a) != len(b) {
		return false
	}
	for i := range a {
		if a[i] != b[i] {
			return false
		}
	}
	return true
}

func containsArg(args []string, target string) bool {
	for _, a := range args {
		if a == target {
			return true
		}
	}
	return false
}

func containsArgAfter(args []string, before, target string) bool {
	for i, a := range args {
		if a == before && i+1 < len(args) && args[i+1] == target {
			return true
		}
	}
	return false
}
