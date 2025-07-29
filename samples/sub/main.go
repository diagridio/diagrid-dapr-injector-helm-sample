package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"time"

	dapr "github.com/dapr/go-sdk/client"
	"github.com/dapr/go-sdk/service/common"
	daprd "github.com/dapr/go-sdk/service/http"
)

const (
	pubsubName = "pubsub"
	topic      = "topic"
)

type service struct {
	client dapr.Client
	server common.Service
}

type message struct {
	ID        string    `json:"id"`
	Timestamp time.Time `json:"timestamp"`
	Content   string    `json:"content"`
}

func NewService() *service {
	daprClient, err := dapr.NewClient()
	if err != nil {
		panic(err)
	}

	s := daprd.NewService(":8080")
	if s == nil {
		panic("Failed to create Dapr service")
	}

	return &service{
		client: daprClient,
		server: s,
	}
}

func main() {
	fmt.Println("Hello! I'm the sub service!")
	s := NewService()
	log.SetFlags(log.LstdFlags)
	defer s.client.Close()

	if err := s.server.AddTopicEventHandler(&common.Subscription{
		PubsubName: pubsubName,
		Topic:      topic,
		Route:      "/topic",
	}, s.handleMessage); err != nil {
		log.Fatalf("Error adding topic event handler: %v", err)
	}

	if err := s.server.Start(); err != nil && err != http.ErrServerClosed {
		log.Fatalf("Error starting service: %v", err)
	}
}

func (s *service) handleMessage(ctx context.Context, e *common.TopicEvent) (retry bool, err error) {
	jsonData, err := json.Marshal(e.Data)
	if err != nil {
		log.Printf("Error marshaling message: %v", err)
		return false, err
	}

	var msg message
	if err := json.Unmarshal(jsonData, &msg); err != nil {
		log.Printf("Error unmarshaling message: %v", err)
		return false, err
	}

	log.Printf("Processing message - ID: %s, Timestamp: %s, Content: %s",
		msg.ID, msg.Timestamp.Format(time.RFC3339), msg.Content)

	key := msg.ID
	err = s.client.SaveState(ctx, "statestore", key, jsonData, nil)
	if err != nil {
		log.Printf("Error saving state: %v", err)
		return false, err
	}

	log.Printf("Successfully processed message: %s", msg.ID)
	return false, nil
}
