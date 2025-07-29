package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"time"

	dapr "github.com/dapr/go-sdk/client"
	"github.com/google/uuid"
)

const (
	pubsubName = "pubsub"
	topic      = "topic"
)

type service struct {
	client dapr.Client
}

func NewService() *service {
	daprClient, err := dapr.NewClient()
	if err != nil {
		panic(err)
	}
	return &service{
		client: daprClient,
	}
}

func main() {
	fmt.Println("Hello! I'm the pub service!")
	s := NewService()
	log.SetFlags(log.LstdFlags)
	defer s.client.Close()

	go func() {
		http.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
			w.WriteHeader(http.StatusOK)
			w.Write([]byte("ok"))
		})

		log.Println("Starting HTTP server on :8080")
		if err := http.ListenAndServe(":8080", nil); err != nil {
			log.Fatalf("Failed to start HTTP server: %v", err)
		}
	}()

	for {
		time.Sleep(5 * time.Second)
		err := s.publish()
		if err != nil {
			log.Printf("Error calling pub: %s\n", err)
			continue
		}
	}
}

type message struct {
	ID        string    `json:"id"`
	Timestamp time.Time `json:"timestamp"`
	Content   string    `json:"content"`
}

func (s *service) publish() error {
	msg := message{
		ID:        uuid.New().String(),
		Timestamp: time.Now(),
		Content:   fmt.Sprintf("Message published at %s", time.Now().Format(time.RFC3339)),
	}
	msgBytes, err := json.Marshal(msg)
	if err != nil {
		log.Printf("Error marshaling message: %v", err)
		return err
	}
	err = s.client.PublishEvent(context.Background(), pubsubName, topic, msgBytes)
	if err != nil {
		log.Printf("Error publishing message: %v", err)
		return err
	}

	log.Printf("Published message: %s", msg.ID)
	return nil
}
