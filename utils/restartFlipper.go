package utils

import (
	"flipper_utils/config"
	"fmt"
	"os/exec"
	"path"
	"path/filepath"
	"runtime"
)

func RestartFlipper(cfg *config.Config) {
	//config
	flipperNameToChangeTo := cfg.FlipperName
	flipperToolsFolder := cfg.FlipperToolsFolder

	restartProcess(flipperNameToChangeTo, path.Join(flipperToolsFolder, flipperNameToChangeTo))
}

func restartProcess(name, path string) {
	// 1. Terminate existing process
	var killCmd *exec.Cmd
	if runtime.GOOS == "windows" {
		killCmd = exec.Command("taskkill", "/F", "/IM", name)
	} else {
		killCmd = exec.Command("pkill", "-f", name)
	}

	// Ignore error in case the process isn't currently running
	_ = killCmd.Run()

	// 2. Prepare the new instance
	startCmd := exec.Command(path)

	// SET THE WORKING DIRECTORY
	// filepath.Dir(path) gets the folder containing the executable
	startCmd.Dir = filepath.Dir(path)

	// 3. Start the new instance
	// Use Start() so the restarter doesn't wait for the app to close
	err := startCmd.Start()
	if err != nil {
		fmt.Printf("Failed to restart: %v\n", err)
		return
	}

	fmt.Printf("Restarted %s successfully in directory: %s\n", name, startCmd.Dir)
}
