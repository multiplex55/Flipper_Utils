package config

type Config struct {
	PathToFlipper        string `json:"pathToFlipper"`
	PathToExportLocation string `json:"pathToExportLocation"`
	PathToFlipperBuild   string `json:"pathToFlipperBuild"`
	FlipperOriginalName  string `json:"flipperOriginalName"`
	FlipperName          string `json:"flipperName"`
	FlipperToolsFolder   string `json:"flipperToolsFolder"`
}
