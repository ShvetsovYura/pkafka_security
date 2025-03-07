package main

import (
	"context"
	"encoding/json"
	"log"
	"log/slog"
	"os"
	"os/signal"
	"sync"
	"syscall"
	"time"

	"github.com/confluentinc/confluent-kafka-go/kafka"
	"gopkg.in/yaml.v3"
)

var logger slog.Logger

func loggerInit() {
	handler := slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{
		Level: slog.LevelDebug,
	})
	logger = *slog.New(handler)
}

func main() {
	loggerInit()
	data, err := os.ReadFile("cmd/config.yml")
	if err != nil {
		logger.Warn(err.Error())
		return
	}

	var config map[string]any

	err = yaml.Unmarshal(data, &config)
	if err != nil {
		logger.Error(err.Error())
		return
	}
	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer func() {
		stop()
	}()
	wg := &sync.WaitGroup{}
	wg.Add(2)
	go StartProducer(ctx, wg, config["topic"].(string), config["producer"].(map[string]any))
	go StartConsumer(ctx, wg, config["topic"].(string), config["consumer"].(map[string]any))
	wg.Wait()
}

// User is a simple record example
type User struct {
	Name           string `json:"name"`
	FavoriteNumber int64  `json:"favorite_number"`
	FavoriteColor  string `json:"favorite_color"`
}

func StartConsumer(ctx context.Context, wg *sync.WaitGroup, topic string, cfg map[string]any) {
	var cfgMap kafka.ConfigMap = kafka.ConfigMap{}

	for k, v := range cfg {
		cfgMap.SetKey(k, v)
	}
	cfgMap.SetKey("group.id", cfg["group.id"].(string))

	// Создание нового consumer
	c, err := kafka.NewConsumer(&cfgMap)
	if err != nil {
		log.Fatalf("Failed to create consumer: %s\n", err)
	}
	defer c.Close()

	err = c.SubscribeTopics([]string{topic}, nil)
	if err != nil {
		log.Fatalf("Failed to subscribe to topic: %s\n", err)
	}

	logger.Info("Consumer started and subscribed to topic", slog.Any("consumer", c), slog.String("topic", topic))

	// Чтение сообщений
	for {
		select {
		case <-ctx.Done():
			logger.Info("Получен сигнал выхода, остановка консьюмера...")
			wg.Done()
		default:
			msg, err := c.ReadMessage(3 * time.Second)
			if err != nil {
				// Если произошла ошибка, выводим ее и продолжаем
				logger.Warn("Error while reading message", slog.Any("error", err))
				continue
			}

			// Десериализация сообщения
			var user User
			if err := json.Unmarshal(msg.Value, &user); err != nil {
				logger.Warn("Failed to deserialize message", slog.Any("error", err))
				continue
			}

			logger.Info("Received message", slog.Any("value", user))
		}

	}
}

func StartProducer(ctx context.Context, wg *sync.WaitGroup, topic string, cfg map[string]any) {
	var cfgMap kafka.ConfigMap = kafka.ConfigMap{}

	for k, v := range cfg {
		cfgMap.SetKey(k, v)
	}

	p, err := kafka.NewProducer(&cfgMap)
	if err != nil {
		log.Fatalf("Failed to create producer: %s\n", err)
	}
	deliveryChan := make(chan kafka.Event)

	defer func() {
		p.Close()
		close(deliveryChan)
	}()

	logger.Info("Created Producer", slog.Any("producer", p))

	value := User{
		Name:           "First user",
		FavoriteNumber: 42,
		FavoriteColor:  "blue",
	}
	payload, err := json.Marshal(value)
	if err != nil {
		logger.Warn("Failed to serialize payload", slog.Any("error", err))
	}

	timer := time.NewTicker(1 * time.Second)
	for {
		select {
		case <-ctx.Done():
			logger.Info("Получен сигнал выхода, остановка продьюсера...")
			wg.Done()
		case <-timer.C:
			err = p.Produce(&kafka.Message{
				TopicPartition: kafka.TopicPartition{Topic: &topic, Partition: kafka.PartitionAny},
				Value:          payload,
			}, deliveryChan)
			if err != nil {
				logger.Warn("Produce failed", slog.Any("error", err))
			}

			e := <-deliveryChan
			m := e.(*kafka.Message)

			if m.TopicPartition.Error != nil {
				logger.Info("Delivery failed", slog.Any("error", m.TopicPartition.Error))
			} else {
				logger.Info("Delivered message ",
					slog.String("topic", *m.TopicPartition.Topic),
					slog.Int("partition", int(m.TopicPartition.Partition)),
					slog.Any("offset", m.TopicPartition.Offset))
			}
		}

	}

}
