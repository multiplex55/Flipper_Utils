package main

import (
	"encoding/json"
	"flipper_utils/config"
	"flipper_utils/utils"
	"log"
	"os"

	"github.com/charmbracelet/huh"
)

func main() {
	file, err := os.Open("flipperUtilConfig.json")
	if err != nil {
		log.Fatal("Could not find or open config file, expecting flipperUtilsCofig.json")
	}
	defer file.Close()

	//parse config
	var cfg config.Config
	decoder := json.NewDecoder(file)
	if err := decoder.Decode(&cfg); err != nil {
		log.Fatalf("Failed to decode JSON: %v", err)
	}

	//HUH
	var choice string

	// Create the selection menu
	form := huh.NewForm(
		huh.NewGroup(
			huh.NewSelect[string]().
				Title("Choose an operation").
				Options(
					huh.NewOption("Zip Flipper", "zip"),
					huh.NewOption("Move Flipper To Tools", "move"),
					huh.NewOption("Restart Flipper", "restart"),
					huh.NewOption("Quit", "quit"),
				).
				Value(&choice),
		),
	)

	if err := form.Run(); err != nil {
		log.Fatal(err)
	}

	// Execute based on choice
	switch choice {
	case "zip":
		utils.ZipFlipper(&cfg)
	case "move":
		utils.MoveFlipper(&cfg)
	case "restart":
		utils.RestartFlipper(&cfg)
	case "quit":
		os.Exit(0)
	}

}
