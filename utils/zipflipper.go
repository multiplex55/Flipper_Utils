package utils

import (
	"archive/zip"
	"flipper_utils/config"
	"log"
	"os"
	"path"
	"path/filepath"
	"time"
)

func ZipFlipper(cfg *config.Config) {
	//config
	pathToFlipper := cfg.PathToFlipper
	pathToExportLocation := cfg.PathToExportLocation
	fileToRemove := ".env"
	log.Printf("Starting\n")

	//copy
	log.Printf("%v start copying\n", time.Now())
	copyFlipperFolder(pathToFlipper, pathToExportLocation)
	log.Printf("%v done copying\n", time.Now())

	//remove from copy
	log.Printf("%v start remove\n", time.Now())
	removeEnvFile(pathToExportLocation, fileToRemove)
	log.Printf("%v done remove\n", time.Now())

	//zip
	log.Printf("%v start zip\n", time.Now())
	archiveFlipperFolder(pathToExportLocation)
	log.Printf("%v done zip\n", time.Now())

	//delete copy
	log.Printf("%v start remove copy\n", time.Now())
	deleteCopiedFlipperFolder(pathToExportLocation)
	log.Printf("%v done remove copy\n", time.Now())

}

func deleteCopiedFlipperFolder(pathToExportLocation string) {
	err := os.RemoveAll(pathToExportLocation)
	if err != nil {
		log.Fatalf("Couldn't remove the copied directory for some reason? : %v\n", pathToExportLocation)
	}
}

func archiveFlipperFolder(pathToExportLocation string) {
	out, _ := os.Create(path.Join(
		filepath.Dir(pathToExportLocation), "multi_flipper.zip"))
	defer out.Close()

	w := zip.NewWriter(out)
	defer w.Close()

	// Addfs automatically walks and adds the entire directory
	//Note: os.DiFS(".") uses teh current directory as the root
	w.AddFS(os.DirFS(pathToExportLocation))
}

func removeEnvFile(pathToExportLocation string, fileToRemove string) {
	fullPathOfFileToRemove := path.Join(pathToExportLocation, fileToRemove)
	err := os.Remove(fullPathOfFileToRemove)

	if err != nil {
		log.Fatalf("Could not find file to remove: %v", fullPathOfFileToRemove)
	}
}

func copyFlipperFolder(pathToFlipper, pathToExportLocation string) {
	srcFS := os.DirFS(pathToFlipper)

	err := os.CopyFS(pathToExportLocation, srcFS)
	if err != nil {
		log.Fatalf("Failed to copy directory: %v", err)
	}

}
