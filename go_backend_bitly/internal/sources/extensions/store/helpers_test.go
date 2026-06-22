package store

import "testing"

func TestNormalizeStoreID(t *testing.T) {
	tests := []struct{ in, want string }{
		{"My-Ext", "my-ext"},
		{"My_Ext", "my-ext"},
		{"My Ext", "my-ext"},
		{"UPPERCASE", "uppercase"},
		{"mix_Ed", "mix-ed"},
	}
	for _, tt := range tests {
		if got := normalizeStoreID(tt.in); got != tt.want {
			t.Errorf("normalizeStoreID(%q) = %q, want %q", tt.in, got, tt.want)
		}
	}
}

func TestCompareVersions(t *testing.T) {
	tests := []struct{ v1, v2 string; want int }{
		{"1.0", "1.0", 0},
		{"1.0", "2.0", -1},
		{"2.0", "1.0", 1},
		{"v1.0", "1.0", 0},
		{"1.0.0", "1.0", 0},
		{"1.0", "1.0.1", -1},
		{"1.0.1", "1.0", 1},
		{"2", "1.9", 1},
	}
	for _, tt := range tests {
		if got := compareVersions(tt.v1, tt.v2); got != tt.want {
			t.Errorf("compareVersions(%q, %q) = %d, want %d", tt.v1, tt.v2, got, tt.want)
		}
	}
}

func TestContainsIgnoreCase(t *testing.T) {
	tests := []struct{ s, substr string; want bool }{
		{"Hello World", "hello", true},
		{"Hello World", "world", true},
		{"Hello World", "xyz", false},
		{"", "", true},
		{"Hello", "", true},
		{"", "a", false},
	}
	for _, tt := range tests {
		if got := containsIgnoreCase(tt.s, tt.substr); got != tt.want {
			t.Errorf("containsIgnoreCase(%q, %q) = %v, want %v", tt.s, tt.substr, got, tt.want)
		}
	}
}
