package utils

import (
	"archive/zip"
	"errors"
	"flipper_utils/config"
	"io/fs"
	"log"
	"os"
	"path/filepath"
	"strings"
	"time"
)

const archiveName = "multi_flipper.zip"

// ZipFlipper copies the configured flipper project to the export location,
// removes generated/build-only artifacts, zips the cleaned copy, then removes
// the temporary copied folder.
func ZipFlipper(cfg *config.Config) {
	pathToFlipper := cfg.PathToFlipper
	pathToExportLocation := cfg.PathToExportLocation

	log.Printf("Starting zip export")

	log.Printf("%v start checking for existing zip", time.Now())
	deleteExistingArchive(pathToExportLocation)
	log.Printf("%v done checking for existing zip", time.Now())

	log.Printf("%v start copying", time.Now())
	copyFlipperFolder(pathToFlipper, pathToExportLocation)
	log.Printf("%v done copying", time.Now())

	log.Printf("%v start cleanup", time.Now())
	removeBuildArtifacts(pathToExportLocation)
	log.Printf("%v done cleanup", time.Now())

	log.Printf("%v start zip", time.Now())
	archiveFlipperFolder(pathToExportLocation)
	log.Printf("%v done zip", time.Now())

	log.Printf("%v start remove copy", time.Now())
	deleteCopiedFlipperFolder(pathToExportLocation)
	log.Printf("%v done remove copy", time.Now())
}

func deleteExistingArchive(pathToExportLocation string) {
	zipLocation := filepath.Join(filepath.Dir(pathToExportLocation), archiveName)

	if err := os.Remove(zipLocation); err != nil && !errors.Is(err, os.ErrNotExist) {
		log.Fatalf("remove existing archive %q: %v", zipLocation, err)
	}
}

func deleteCopiedFlipperFolder(pathToExportLocation string) {
	if err := os.RemoveAll(pathToExportLocation); err != nil {
		log.Fatalf("remove copied directory %q: %v", pathToExportLocation, err)
	}
}

func archiveFlipperFolder(pathToExportLocation string) {
	zipLocation := filepath.Join(filepath.Dir(pathToExportLocation), archiveName)

	out, err := os.Create(zipLocation)
	if err != nil {
		log.Fatalf("create archive %q: %v", zipLocation, err)
	}
	defer func() {
		if err := out.Close(); err != nil {
			log.Fatalf("close archive file %q: %v", zipLocation, err)
		}
	}()

	w := zip.NewWriter(out)
	defer func() {
		if err := w.Close(); err != nil {
			log.Fatalf("close zip writer for %q: %v", zipLocation, err)
		}
	}()

	if err := w.AddFS(os.DirFS(pathToExportLocation)); err != nil {
		log.Fatalf("add files to archive %q: %v", zipLocation, err)
	}
}

func copyFlipperFolder(pathToFlipper, pathToExportLocation string) {
	if err := os.RemoveAll(pathToExportLocation); err != nil {
		log.Fatalf("clear export directory %q: %v", pathToExportLocation, err)
	}

	if err := os.CopyFS(pathToExportLocation, os.DirFS(pathToFlipper)); err != nil {
		log.Fatalf("copy %q to %q: %v", pathToFlipper, pathToExportLocation, err)
	}
}

func removeBuildArtifacts(projectRoot string) {
	removeKnownPaths(projectRoot)
	removeGeneratedDirectories(projectRoot)
	removeGeneratedFiles(projectRoot)
}

func removeKnownPaths(projectRoot string) {
	pathsToRemove := []string{
		// Sensitive/local files.
		".env",
		".env.local",
		".env.development.local",
		".env.production.local",
		".env.test.local",

		// Repository metadata.
		".git",
		".github",

		// Root project generated data/build output.
		"assets",
		"build",
		"data",
		"dist",
		"DIST",
		"tmp",
		"temp",
		"coverage",

		// Frontend dependency/build/cache output.
		filepath.Join("frontend", "assets"),
		filepath.Join("frontend", "build"),
		filepath.Join("frontend", "dist"),
		filepath.Join("frontend", "DIST"),
		filepath.Join("frontend", "node_modules"),
		filepath.Join("frontend", ".vite"),
		filepath.Join("frontend", ".vite-temp"),
		filepath.Join("frontend", ".turbo"),
		filepath.Join("frontend", ".next"),
		filepath.Join("frontend", ".nuxt"),
		filepath.Join("frontend", "out"),
		filepath.Join("frontend", "coverage"),
		filepath.Join("frontend", "tmp"),
		filepath.Join("frontend", "temp"),

		// Tauri/Rust generated output.
		filepath.Join("frontend", "src-tauri", "target"),
		filepath.Join("frontend", "src-tauri", "dist"),
		filepath.Join("frontend", "src-tauri", "gen"),
	}

	for _, relativePath := range pathsToRemove {
		removePathIfExists(projectRoot, relativePath)
	}
}

func removeGeneratedDirectories(projectRoot string) {
	generatedDirectoryNames := map[string]struct{}{
		".cache":        {},
		".parcel-cache": {},
		".turbo":        {},
		".vite":         {},
		".vite-temp":    {},
		"build":         {},
		"coverage":      {},
		"debug":         {},
		"dist":          {},
		"DIST":          {},
		"node_modules":  {},
		"obj":           {},
		"out":           {},
		"release":       {},
		"target":        {},
		"tmp":           {},
	}

	walkErr := filepath.WalkDir(projectRoot, func(currentPath string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if !d.IsDir() || currentPath == projectRoot {
			return nil
		}

		name := d.Name()
		if _, shouldRemove := generatedDirectoryNames[name]; !shouldRemove {
			return nil
		}

		if err := os.RemoveAll(currentPath); err != nil {
			return err
		}

		log.Printf("removed generated directory: %s", currentPath)
		return filepath.SkipDir
	})
	if walkErr != nil {
		log.Fatalf("remove generated directories under %q: %v", projectRoot, walkErr)
	}
}

func removeGeneratedFiles(projectRoot string) {
	generatedFileSuffixes := []string{
		".log",
		".tmp",
		".temp",
		".map",
		".tsbuildinfo",
	}

	generatedFileNames := map[string]struct{}{
		"npm-debug.log":      {},
		"yarn-debug.log":     {},
		"yarn-error.log":     {},
		"pnpm-debug.log":     {},
		"bun-debug.log":      {},
		"vite.config.ts.tmp": {},
	}

	walkErr := filepath.WalkDir(projectRoot, func(currentPath string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if d.IsDir() {
			return nil
		}

		name := d.Name()
		if _, shouldRemove := generatedFileNames[name]; shouldRemove {
			return removeGeneratedFile(currentPath)
		}

		for _, suffix := range generatedFileSuffixes {
			if strings.HasSuffix(name, suffix) {
				return removeGeneratedFile(currentPath)
			}
		}

		return nil
	})
	if walkErr != nil {
		log.Fatalf("remove generated files under %q: %v", projectRoot, walkErr)
	}
}

func removeGeneratedFile(filePath string) error {
	if err := os.Remove(filePath); err != nil && !errors.Is(err, os.ErrNotExist) {
		return err
	}

	log.Printf("removed generated file: %s", filePath)
	return nil
}

func removePathIfExists(projectRoot, relativePath string) {
	fullPath := filepath.Join(projectRoot, relativePath)

	if err := os.RemoveAll(fullPath); err != nil {
		log.Fatalf("remove %q: %v", fullPath, err)
	}

	log.Printf("removed if present: %s", fullPath)
}
