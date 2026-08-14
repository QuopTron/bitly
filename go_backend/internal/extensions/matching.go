package extensions

func registerMatching(s *Sandbox) {
	vm := s.VM

	// utils + log + match objects
	registerUtilsObject(vm, s.ID)
	registerConsoleObject(vm, s.ID)

	matchObj := registerMatchObject(vm)
	vm.Set("match", matchObj)
	vm.Set("matching", matchObj)
}
