package main

import (
	"bufio"
	"context"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"time"

	"github.com/aws/aws-lambda-go/lambda"
	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/s3/s3manager"
	"github.com/google/uuid"
)

// Event is the input event for the Lambda function.
type Event struct {
	Targets []string `json:"targets"`
	Args    []string `json:"args"`
	Output  string   `json:"output"`
}

// Response is the output response for the Lambda function.
type Response struct {
	Output string `json:"output"`
	Error  string `json:"error"`
}

// Variables for the nuclei binary, filesystem location, and temporary files
var (
	nucleiBinary    = "/opt/nuclei"
	nucleiTemplates = "/opt/nuclei-templates"
	fileSystem      = "/tmp/"
	targetsFile     = fileSystem + "targets.txt"
	scanOutput      = fileSystem + "output.json"
)

func handler(ctx context.Context, event Event) (Response, error) {
	// Set the $HOME environment so nuclei can write inside of lambda
	os.Setenv("HOME", fileSystem)

	// Check to see if you have Args and Command in the event
	if len(event.Targets) == 0 || len(event.Args) == 0 || event.Output == "" {
		return Response{
			Error: "Nuclei requires a targets, args, and output to run. Please specify the target(s), args, and output within the event.",
		}, nil
	}

	//check to see if any /opt/nuclei-templates* directory exists.
	pattern := "/opt/nuclei-templates*"

	matches, err := filepath.Glob(pattern)

	if err != nil {
		fmt.Printf("Error while matching pattern: %v, can't search for templates directory.\n", err)
	}

	if len(matches) > 0 {
		nucleiTemplates := matches[0]
		fmt.Printf("First directory matching the pattern: %s\n", nucleiTemplates)
	}

	//explicitly set our /opt/nuclei-templates directory, since .templates-config.json appears to be ignored
	event.Args = append(event.Args, "-ud", nucleiTemplates)

	// Check to see if it is a single target or multiple
	if len(event.Targets) == 1 {
		// If it's a single target it prepends -u target to the args
		event.Args = append([]string{"-u", event.Targets[0]}, event.Args...)
	} else {
		// If it's a list of targets write them to a file and prepends -l targets.txt to the args
		targetsFile, err := writeTargets(event.Targets)
		if err != nil {
			return Response{
				Error: err.Error(),
			}, nil
		}
		event.Args = append([]string{"-l", targetsFile}, event.Args...)
	}

	// If the output is json or s3 then output as json
	if event.Output == "json" || event.Output == "s3" {
		event.Args = append(event.Args, "-jsonl", "-o", scanOutput, "-silent")
	}

	// Run the nuclei binary with the command and args
	output, err := runNuclei(event.Args)
	base64output := base64.StdEncoding.EncodeToString([]byte(output))
	if err != nil {
		// Return output as base64 to display in the console
		return Response{
			Output: string(base64output),
			Error:  err.Error(),
		}, nil
	}

	// Send the scan results to the sink
	if event.Output == "json" {
		findings, err := jsonOutputFindings(scanOutput)
		// convert it to json
		jsonFindings, err := json.Marshal(findings)
		if err != nil {
			return Response{
				Output: output,
				Error:  err.Error(),
			}, nil
		}
		return Response{
			Output: string(jsonFindings),
		}, nil
	} else if event.Output == "cmd" {
		return Response{
			Output: string(base64output),
		}, nil
	} else if event.Output == "s3" {
		// Read the findings as []interface{}
		findings, err := jsonOutputFindings(scanOutput)
		if err != nil {
			return Response{
				Output: output,
				Error:  err.Error(),
			}, nil
		}

		if len(findings) == 0 {
			return Response{
				Output: "No findings, better luck next time!",
			}, nil
		}

		// Write the findings to a file and upload to s3
		s3Key, err := writeAndUploadFindings(findings)
		if err != nil {
			return Response{
				Output: output,
				Error:  err.Error(),
			}, nil
		}

		if s3Key == "No findings" {
			return Response{
				Output: "No findings, better luck next time!",
			}, nil
		}

		// Return the s3 key
		return Response{
			Output: s3Key,
		}, nil
	} else {
		return Response{
			Output: output,
			Error:  "Output type not supported. Please specify json or cmd.",
		}, nil
	}
}

// Run Nuclei with the command and args
func runNuclei(args []string) (string, error) {
	// Run the nuclei binary with the command and args
	cmd := exec.Command(nucleiBinary, args...)
	output, err := cmd.CombinedOutput()
	if err != nil {
		return string(output), err
	}
	return string(output), nil
}

// Write targets to a file on disk and return filename
func writeTargets(targets []string) (string, error) {
	// Check if the targets file exists, if it does delete it
	if _, err := os.Stat(targetsFile); err == nil {
		os.Remove(targetsFile)
	}

	// Create a file
	file, err := os.Create(targetsFile)
	if err != nil {
		return "", err
	}
	defer file.Close()

	// Write the list to the file.
	for _, target := range targets {
		_, err := file.WriteString(target + "\n")
		if err != nil {
			// Handle the error.
		}
	}

	// Return the filename
	return targetsFile, nil
}

// jsonFindings reads the output.json file and returns the findings
func jsonOutputFindings(scanOutputFile string) ([]interface{}, error) {
	file, err := os.Open(scanOutputFile)
	if err != nil {
		return nil, err
	}
	defer file.Close()

	// Create a scanner to read the file line by line
	scanner := bufio.NewScanner(file)

	// Iterate through the file and append the findings to the findings array
	var findings []interface{}
	for scanner.Scan() {
		var data interface{}
		if err := json.Unmarshal(scanner.Bytes(), &data); err != nil {
			return nil, err
		}
		findings = append(findings, data)
	}

	// Check for errors while reading the file
	if err := scanner.Err(); err != nil {
		return nil, err
	}

	// Return the findings
	return findings, nil
}

// Takes in []interface{}, iterates through it, writes it to a file based on the date, and uploads it to S3
func writeAndUploadFindings(findings []interface{}) (string, error) {
	// Bucket and region
	region := os.Getenv("AWS_REGION")
	bucket := os.Getenv("BUCKET_NAME")
	// Iterate through the interface and convert to a slice of strings for writing to a file
	var s3Findings []string
	for _, finding := range findings {
		jsonFinding, err := json.Marshal(finding)
		if err != nil {
			return "failed to upload to s3", err
		}
		s3Findings = append(s3Findings, string(jsonFinding))
	}

	if len(s3Findings) == 0 {
		return "No findings", nil
	}

	// Two variables for filename, must be unique on execution, and s3 key partitioned with findings/year/month/day/hour/nuclei-findings-<timestamp>.json
	t := time.Now()
	uuid := uuid.New().String()
	s3Key := fmt.Sprintf("findings/%d/%02d/%02d/%02d/nuclei-findings-%s.json", t.Year(), t.Month(), t.Day(), t.Hour(), uuid)
	filename := fmt.Sprintf("nuclei-findings-%s.json", uuid)

	// Write the findings to a file
	file, err := os.Create(fileSystem + filename)
	if err != nil {
		return "Failed to write to filesystem", err
	}
	defer file.Close()

	// Write the list to the file.
	for _, finding := range s3Findings {
		_, err := file.WriteString(finding + "\n")
		if err != nil {
			return "Failed to write json to file", err
		}
	}

	// Upload the file to S3
	sess, err := session.NewSession(&aws.Config{
		Region: aws.String(region)},
	)
	if err != nil {
		return "Failed to create session", err
	}

	// Create an uploader with the session and default options
	uploader := s3manager.NewUploader(sess)

	findingsFile, err := os.Open(fileSystem + filename)
	if err != nil {
		return "Failed to open file", err
	}

	// Upload the file to S3.
	_, err = uploader.Upload(&s3manager.UploadInput{
		Bucket: aws.String(bucket),
		Key:    aws.String(s3Key),
		Body:   findingsFile,
	})
	if err != nil {
		return "Failed to upload file", err
	}

	// S3 path for the file
	s3uri := fmt.Sprintf("s3://%s/%s", bucket, s3Key)

	// Return the s3 uri after uploading
	return s3uri, nil
}

// Contains checks to see if a string is in a slice of strings
func contains(elems []string, v string) bool {
	for _, s := range elems {
		if v == s {
			return true
		}
	}
	return false
}

func main() {
	lambda.Start(handler)
}
