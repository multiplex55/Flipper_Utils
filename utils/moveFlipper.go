package utils

import (
	"errors"
	"flipper_utils/config"
	"fmt"
	"log"
	"os"
	"path/filepath"
)

func MoveFlipper(cfg *config.Config) {
	//config
	pathToFlipperBuild := cfg.PathToFlipperBuild
	flipperOriginalName := cfg.FlipperOriginalName
	flipperName := cfg.FlipperName
	flipperToolsFolder := cfg.FlipperToolsFolder

	res := checkIfFlipperBuildIsThere(pathToFlipperBuild)

	if !res {
		log.Fatal("Can't find flipper build")
	}

	renameFlipperAndMoveToTools(pathToFlipperBuild, flipperOriginalName, flipperName, flipperToolsFolder)

}

func renameFlipperAndMoveToTools(pathToFlipperBuild, flipperOriginalName, flipperName, flipperToolsFolder string) {
	fullPathToFlipperBuild := filepath.Join(pathToFlipperBuild, flipperOriginalName)
	fullPathToFlipperBuildNewName := filepath.Join(flipperToolsFolder, flipperName)

	//rename the file
	err := os.Rename(fullPathToFlipperBuild, fullPathToFlipperBuildNewName)

	if err != nil {
		log.Fatal("Can't rename or move file")
	}
}

func checkIfFlipperBuildIsThere(pathToFlipperBuild string) bool {

	if _, err := os.Stat(pathToFlipperBuild); err == nil {
		fmt.Println("File exists")
		return true
	} else if errors.Is(err, os.ErrNotExist) {
		fmt.Println("File does not exist")
		return false
	} else {
		// File may or may not exist (e.g., permission denied)
		fmt.Printf("Error checking file: %v\n", err)
	}
	return false
}
