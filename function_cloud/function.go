// Package p contains an HTTP Cloud Function.
package p

import (
	"bytes"
	"fmt"
	"net/http"
	"os/exec"
)

func LogzioHandler(w http.ResponseWriter, r *http.Request) {

	cmd := exec.Command("./telegraf", "--config", "telegraf.conf", "--once")

	var out bytes.Buffer
	var stderr bytes.Buffer

	cmd.Dir = "./serverless_function_source_code"
	cmd.Stdout = &out
	cmd.Stderr = &stderr

	err := cmd.Run()
	if err != nil {
		fmt.Println(fmt.Sprint(err) + ": " + stderr.String())
	}
	fmt.Println(fmt.Sprint(err) + ": " + stderr.String())
}
