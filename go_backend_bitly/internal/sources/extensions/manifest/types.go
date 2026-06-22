package manifest

type ExtensionType string

const (
	ExtensionTypeMetadataProvider ExtensionType = "metadata_provider"
	ExtensionTypeDownloadProvider ExtensionType = "download_provider"
	ExtensionTypeLyricsProvider   ExtensionType = "lyrics_provider"
)

type SettingType string

const (
	SettingTypeString SettingType = "string"
	SettingTypeNumber SettingType = "number"
	SettingTypeBool   SettingType = "boolean"
	SettingTypeSelect SettingType = "select"
	SettingTypeButton SettingType = "button"
)
