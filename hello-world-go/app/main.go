package main

import (
	"context"
	"fmt"
	"html/template"
	"log"
	"net/http"
	"os"
	"strings"
	"k8s.io/client-go/kubernetes"
	"k8s.io/client-go/rest"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

var tmpl *template.Template

func logRequest(next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		log.Printf("Request: %s %s", r.Method, r.URL.Path)
		next.ServeHTTP(w, r)
	}
}

func logResponse(next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		defer func() {
			log.Printf("Response: %s %s", r.Method, r.URL.Path)
		}()
		next.ServeHTTP(w, r)
	}
}

func faviconHandler(w http.ResponseWriter, r *http.Request) {
	w.WriteHeader(http.StatusOK)
}

func healthzHandler(w http.ResponseWriter, r *http.Request) {
	fmt.Println("Healthy!")
	w.WriteHeader(http.StatusOK)
}

func getHostname() string {
	hostname, err := os.Hostname()
	if err != nil {
		log.Println("Error getting hostname:", err)
		return "Unknown"
	}
	return hostname
}

func getRequestHeaders(r *http.Request) http.Header {
	return r.Header
}

func getKubernetesPort() string {
	return os.Getenv("KUBERNETES_SERVICE_PORT")
}

func getKubernetesHost() string {
	return os.Getenv("KUBERNETES_SERVICE_HOST")
}

func getAppIP() string {
	return os.Getenv("HELLO_WORLD_PORT")
}

// a lot of these structs are for later work
func helloHandler(w http.ResponseWriter, r *http.Request) {
	// Check if tmpl is nil
	if tmpl == nil {
        http.Error(w, "Internal server error: Template is nil", http.StatusInternalServerError)
        return
    }

	podName := os.Getenv("POD_NAME")
	podNamespace := os.Getenv("POD_NAMESPACE")
	podUID := os.Getenv("POD_UID")
	podCreationTimestamp := os.Getenv("POD_CREATION_TIMESTAMP")
	podLabels := parseMapEnv(os.Getenv("POD_LABELS"))
	podAnnotations := parseMapEnv(os.Getenv("POD_ANNOTATIONS"))

	data := struct {
		Hostname             string
		PodName              string
		PodNamespace         string
		PodUID               string
		PodCreationTimestamp string
		PodLabels            map[string]string
		PodAnnotations       map[string]string
		Headers              http.Header // Define the Headers field
		AppIP                string
		K8sHost              string
		K8sPort              string
	}{
		Hostname:             getHostname(),
		Headers:              getRequestHeaders(r), // Set the Headers field
		AppIP:                getAppIP(),
		K8sHost:              getKubernetesHost(),
		K8sPort:              getKubernetesPort(),
		PodName:              podName,
		PodNamespace:         podNamespace,
		PodUID:               podUID,
		PodCreationTimestamp: podCreationTimestamp,
		PodLabels:            podLabels,
		PodAnnotations:       podAnnotations,
	}

	if err := tmpl.Execute(w, data); err != nil {
		log.Println("Error executing template:", err)
		http.Error(w, "Internal server error", http.StatusInternalServerError)
		return
	}
}

func parseMapEnv(envStr string) map[string]string {
	m := make(map[string]string)
	for _, kv := range strings.Split(envStr, ",") {
		pair := strings.Split(kv, "=")
		if len(pair) == 2 {
			m[pair[0]] = pair[1]
		}
	}
	return m
}

func containerInfoHandler(w http.ResponseWriter, r *http.Request) {
	if _, hostExists := os.LookupEnv("KUBERNETES_SERVICE_HOST"); !hostExists {
        // Kubernetes environment variables are not present, so this container is not running in Kubernetes
        fmt.Fprintln(w, "This container isn't running in Kubernetes.")
        return
    }
	config, err := rest.InClusterConfig()
	if err != nil {
		errorMsg := fmt.Sprintf("Error initializing Kubernetes client config: %s", err)
		log.Println(errorMsg)
		http.Error(w, errorMsg, http.StatusInternalServerError)
		return
	}

	clientset, err := kubernetes.NewForConfig(config)
	if err != nil {
		errorMsg := fmt.Sprintf("Error creating Kubernetes client: %s", err)
		log.Println(errorMsg)
		http.Error(w, errorMsg, http.StatusInternalServerError)
		return
	}

	podName := os.Getenv("POD_NAME")
	podNamespace := os.Getenv("POD_NAMESPACE")

	pod, err := clientset.CoreV1().Pods(podNamespace).Get(context.TODO(), podName, metav1.GetOptions{})
	if err != nil {
		errorMsg := fmt.Sprintf("Error retrieving pod information: %s", err)
		log.Println(errorMsg)
		http.Error(w, errorMsg, http.StatusInternalServerError)
		return
	}

	var containerInfo strings.Builder
	for _, container := range pod.Spec.Containers {
		containerInfo.WriteString("Container Name: " + container.Name + "\n")
		containerInfo.WriteString("Image: " + container.Image + "\n")
		containerInfo.WriteString("Ports:\n")
		for _, port := range container.Ports {
			containerInfo.WriteString(fmt.Sprintf("- %d:%d\n", port.ContainerPort, port.HostPort))
		}
		containerInfo.WriteString("\n")
	
		// Additional Information
		containerInfo.WriteString("Namespace: " + pod.Namespace + "\n")
	
		containerInfo.WriteString("Environment Variables:\n")
		for _, envVar := range container.Env {
			containerInfo.WriteString(fmt.Sprintf("- %s: %s\n", envVar.Name, envVar.Value))
		}
	
		containerInfo.WriteString("Resources:\n")
		containerInfo.WriteString(fmt.Sprintf("- CPU Limit: %s\n", container.Resources.Limits.Cpu().String()))
		containerInfo.WriteString(fmt.Sprintf("- Memory Limit: %s\n", container.Resources.Limits.Memory().String()))
	
		containerInfo.WriteString("Command:\n")
		containerInfo.WriteString(fmt.Sprintf("- %s\n", strings.Join(container.Command, " ")))
	
		containerInfo.WriteString("Args:\n")
		containerInfo.WriteString(fmt.Sprintf("- %s\n", strings.Join(container.Args, " ")))
	
		containerInfo.WriteString("Volume Mounts:\n")
		for _, volumeMount := range container.VolumeMounts {
			containerInfo.WriteString(fmt.Sprintf("- Name: %s, Mount Path: %s\n", volumeMount.Name, volumeMount.MountPath))
		}
	}

	w.Header().Set("Content-Type", "text/plain")
	w.Write([]byte(containerInfo.String()))
}

func main() {
    port := os.Getenv("PORT")
    if port == "" {
        port = "8080"
    }

    fmt.Printf("Ready to receive requests on port %s\n", port)

    // Initialize the template by parsing the index.html file
    var err error
    tmpl, err = template.ParseFiles("/app/templates/index.html")
    if err != nil {
        log.Fatal("Error parsing template:", err)
    }

    // Serve static files
    fs := http.FileServer(http.Dir("./static/img"))
    http.Handle("/static/img/", http.StripPrefix("/static/img/", fs))

    // Log each request and its response
    http.HandleFunc("/favicon.ico", logRequest(logResponse(faviconHandler)))
    http.HandleFunc("/healthz", logRequest(logResponse(healthzHandler)))
    http.HandleFunc("/", logRequest(logResponse(helloHandler)))
    http.HandleFunc("/container-info", logRequest(logResponse(containerInfoHandler)))
    log.Fatal(http.ListenAndServe(fmt.Sprintf(":%s", port), nil))
}