/*
Long-running entrypoint for the Dapr workflow order-processor.

The workflow and activities in workflow.go and models.go are taken verbatim from
the upstream quickstart (dapr/quickstarts workflows/go/sdk/order-processor).
Only this entrypoint differs: upstream is a console app that places one order and
exits, which cannot run as a Kubernetes Deployment. This version registers the
same workflow and activities and then serves HTTP so orders can be placed and
inspected in-cluster.
*/
package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"time"

	"github.com/dapr/durabletask-go/workflow"
	"github.com/dapr/go-sdk/client"
)

var (
	stateStoreName  = "statestore"
	workflowName    = "OrderProcessingWorkflow"
	defaultItemName = "cars"
)

var inventory = []InventoryItem{
	{ItemName: "paperclip", PerItemCost: 5, Quantity: 100},
	{ItemName: "cars", PerItemCost: 5000, Quantity: 10},
	{ItemName: "computers", PerItemCost: 500, Quantity: 100},
}

type server struct {
	wfClient   *workflow.Client
	daprClient client.Client
}

func main() {
	fmt.Println("*** Dapr Workflow order-processor (HTTP)")

	r := workflow.NewRegistry()
	if err := r.AddWorkflow(OrderProcessingWorkflow); err != nil {
		log.Fatal(err)
	}
	for _, a := range []workflow.Activity{NotifyActivity, RequestApprovalActivity, VerifyInventoryActivity, ProcessPaymentActivity, UpdateInventoryActivity} {
		if err := r.AddActivity(a); err != nil {
			log.Fatal(err)
		}
	}

	wfClient, err := client.NewWorkflowClient()
	if err != nil {
		log.Fatalf("failed to initialise workflow client: %v", err)
	}
	if err := wfClient.StartWorker(context.Background(), r); err != nil {
		log.Fatal(err)
	}
	log.Println("workflow worker started")

	daprClient, err := client.NewClient()
	if err != nil {
		log.Fatal(err)
	}
	defer daprClient.Close()

	if err := restockInventory(daprClient, inventory); err != nil {
		log.Fatalf("failed to restock: %v", err)
	}

	s := &server{wfClient: wfClient, daprClient: daprClient}

	mux := http.NewServeMux()
	mux.HandleFunc("GET /health", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("ok"))
	})
	mux.HandleFunc("POST /orders", s.placeOrder)
	mux.HandleFunc("GET /orders/{id}", s.getOrder)
	mux.HandleFunc("POST /orders/{id}/approve", s.approveOrder)

	log.Println("listening on :8080")
	if err := http.ListenAndServe(":8080", mux); err != nil {
		log.Fatalf("failed to start HTTP server: %v", err)
	}
}

type orderRequest struct {
	ItemName string `json:"item_name"`
	Quantity int    `json:"quantity"`
}

// placeOrder schedules an OrderProcessingWorkflow. The optional delaySeconds
// query parameter defers the start via WithStartTime, which the Dapr scheduler
// is responsible for firing.
func (s *server) placeOrder(w http.ResponseWriter, r *http.Request) {
	var req orderRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, fmt.Sprintf("invalid order: %v", err), http.StatusBadRequest)
		return
	}
	if req.ItemName == "" {
		req.ItemName = defaultItemName
	}
	if req.Quantity <= 0 {
		req.Quantity = 1
	}

	cost, ok := perItemCost(req.ItemName)
	if !ok {
		http.Error(w, fmt.Sprintf("unknown item %q", req.ItemName), http.StatusBadRequest)
		return
	}

	payload := OrderPayload{
		ItemName:  req.ItemName,
		Quantity:  req.Quantity,
		TotalCost: cost * req.Quantity,
	}

	opts := []workflow.NewWorkflowOptions{workflow.WithInput(payload)}
	if v := r.URL.Query().Get("delaySeconds"); v != "" {
		d, err := time.ParseDuration(v + "s")
		if err != nil {
			http.Error(w, fmt.Sprintf("invalid delaySeconds: %v", err), http.StatusBadRequest)
			return
		}
		opts = append(opts, workflow.WithStartTime(time.Now().UTC().Add(d)))
		log.Printf("scheduling %s order to start in %s", req.ItemName, d)
	}

	id, err := s.wfClient.ScheduleWorkflow(r.Context(), workflowName, opts...)
	if err != nil {
		http.Error(w, fmt.Sprintf("failed to start workflow: %v", err), http.StatusInternalServerError)
		return
	}

	log.Printf("scheduled workflow %s (%d x %s, total %d)", id, payload.Quantity, payload.ItemName, payload.TotalCost)
	writeJSON(w, http.StatusAccepted, map[string]any{"id": id, "order": payload})
}

// getOrder reports the current state of a workflow instance.
func (s *server) getOrder(w http.ResponseWriter, r *http.Request) {
	id := r.PathValue("id")
	meta, err := s.wfClient.FetchWorkflowMetadata(r.Context(), id, workflow.WithFetchPayloads(true))
	if err != nil {
		http.Error(w, fmt.Sprintf("failed to get workflow %s: %v", id, err), http.StatusNotFound)
		return
	}

	writeJSON(w, http.StatusOK, map[string]any{
		"id":           meta.InstanceId,
		"name":         meta.Name,
		"status":       meta.RuntimeStatus.String(),
		"customStatus": meta.CustomStatus.GetValue(),
		"input":        meta.Input.GetValue(),
		"output":       meta.Output.GetValue(),
		"createdAt":    meta.CreatedAt.AsTime(),
		"lastUpdated":  meta.LastUpdatedAt.AsTime(),
	})
}

// approveOrder raises the manager_approval event the workflow waits for when an
// order total exceeds the approval threshold.
func (s *server) approveOrder(w http.ResponseWriter, r *http.Request) {
	id := r.PathValue("id")
	if err := s.wfClient.RaiseEvent(r.Context(), id, "manager_approval"); err != nil {
		http.Error(w, fmt.Sprintf("failed to approve %s: %v", id, err), http.StatusInternalServerError)
		return
	}
	log.Printf("raised manager_approval for %s", id)
	writeJSON(w, http.StatusOK, map[string]string{"id": id, "event": "manager_approval"})
}

func perItemCost(item string) (int, bool) {
	for _, i := range inventory {
		if i.ItemName == item {
			return i.PerItemCost, true
		}
	}
	return 0, false
}

func restockInventory(daprClient client.Client, inventory []InventoryItem) error {
	for _, item := range inventory {
		itemSerialized, err := json.Marshal(item)
		if err != nil {
			return err
		}
		fmt.Printf("adding base stock item: %s\n", item.ItemName)
		if err := daprClient.SaveState(context.Background(), stateStoreName, item.ItemName, itemSerialized, nil); err != nil {
			return err
		}
	}
	return nil
}

func writeJSON(w http.ResponseWriter, code int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(code)
	if err := json.NewEncoder(w).Encode(v); err != nil {
		log.Printf("error writing response: %v", err)
	}
}
