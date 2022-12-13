// Package p contains an HTTP Cloud Function.
package p

import (
	"fmt"
	"net/http"
	"os/exec"
)

func LogzioHandler(w http.ResponseWriter, r *http.Request) {

	app := "./telegraf"

	arg0 := "--config"
	arg1 := "telegraf.conf"
	arg2 := "--once"

	cmd := exec.Command(app, arg0, arg1, arg2)
	stdout, err := cmd.Output()

	if err != nil {
		fmt.Println(err.Error())
		return
	}

	// Print the output
	fmt.Println(string(stdout))
}
