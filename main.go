package main

import (
	"net/http"

	"github.com/gin-gonic/gin"
)

const (
	webPort = "8000"
	webRoot = "./web/template"
)

func main() {
	router := gin.Default()
	router.LoadHTMLGlob(webRoot + "/*")
	//router.LoadHTMLFiles("templates/template1.html", "templates/template2.html")
	router.GET("/", func(c *gin.Context) {
		c.HTML(http.StatusOK, "index.tmpl", gin.H{
			"title": "Hello World",
		})
	})

	runURI := ":" + webPort

	_ = router.Run(runURI)
}
