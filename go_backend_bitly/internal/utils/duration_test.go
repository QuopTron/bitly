package utils

import "testing"

func TestFormatDuration(t *testing.T) {
	tests := []struct {
		name string
		ms   int64
		want string
	}{
		{"zero", 0, "0:00"},
		{"just seconds", 5000, "0:05"},
		{"one minute", 60000, "1:00"},
		{"minutes and seconds", 125000, "2:05"},
		{"one hour", 3600000, "1:00:00"},
		{"hours and minutes", 3660000, "1:01:00"},
		{"full HMS", 3661000, "1:01:01"},
		{"large duration", 90061000, "25:01:01"},
		{"seconds only less than 10", 3000, "0:03"},
		{"exact hour", 7200000, "2:00:00"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := FormatDuration(tt.ms)
			if got != tt.want {
				t.Errorf("FormatDuration(%d) = %q, want %q", tt.ms, got, tt.want)
			}
		})
	}
}

func TestParseDuration(t *testing.T) {
	tests := []struct {
		name    string
		input   string
		want    int64
		wantErr bool
	}{
		{"mm:ss", "2:30", 150000, false},
		{"h:mm:ss", "1:02:30", 3750000, false},
		{"zero mm:ss", "0:00", 0, false},
		{"only seconds", "0:05", 5000, false},
		{"large hours", "25:01:01", 90061000, false},
		{"empty string", "", 0, true},
		{"invalid format", "abc", 0, true},
		{"too many colons", "1:2:3:4", 0, true},
		{"single number", "5", 0, true},
		{"mm only with leading", "01:00", 60000, false},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got, err := ParseDuration(tt.input)
			if (err != nil) != tt.wantErr {
				t.Errorf("ParseDuration(%q) error = %v, wantErr = %v", tt.input, err, tt.wantErr)
				return
			}
			if got != tt.want {
				t.Errorf("ParseDuration(%q) = %d, want %d", tt.input, got, tt.want)
			}
		})
	}
}

func TestFormatParseRoundTrip(t *testing.T) {
	inputs := []int64{0, 5000, 60000, 125000, 3600000, 3661000, 90061000}
	for _, ms := range inputs {
		formatted := FormatDuration(ms)
		parsed, err := ParseDuration(formatted)
		if err != nil {
			t.Errorf("ParseDuration(FormatDuration(%d)) = %q, unexpected error: %v", ms, formatted, err)
			continue
		}
		if parsed != ms {
			t.Errorf("round trip: FormatDuration(%d) = %q, ParseDuration = %d", ms, formatted, parsed)
		}
	}
}
