package function

import (
	"context"
	"fmt"
	"os"
	"strconv"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/credentials"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb/types"
)

// DynamoDBClient wraps the AWS DynamoDB client
type DynamoDBClient struct {
	client       *dynamodb.Client
	mappingTable string
	counterTable string
}

// URLMapping represents a URL mapping in DynamoDB
type URLMapping struct {
	Hash         string
	OriginalURL  string
	CreatedAt    int64
	ClickCount   int64
	LastAccessed int64
}

// NewDynamoDBClient creates a new DynamoDB client
func NewDynamoDBClient() (*DynamoDBClient, error) {
	endpoint := os.Getenv("DYNAMODB_ENDPOINT")
	if endpoint == "" {
		endpoint = "http://10.0.1.2:8000"
	}

	region := os.Getenv("AWS_REGION")
	if region == "" {
		region = "us-east-1"
	}

	mappingTable := os.Getenv("DYNAMODB_TABLE")
	if mappingTable == "" {
		mappingTable = "url_mappings"
	}

	counterTable := os.Getenv("COUNTER_TABLE")
	if counterTable == "" {
		counterTable = "url_counter"
	}

	// Configure custom endpoint resolver for DynamoDB Local
	customResolver := aws.EndpointResolverWithOptionsFunc(func(service, region string, options ...interface{}) (aws.Endpoint, error) {
		return aws.Endpoint{
			URL:           endpoint,
			SigningRegion: region,
		}, nil
	})

	cfg, err := config.LoadDefaultConfig(context.TODO(),
		config.WithRegion(region),
		config.WithEndpointResolverWithOptions(customResolver),
		config.WithCredentialsProvider(credentials.NewStaticCredentialsProvider("dummy", "dummy", "")),
	)
	if err != nil {
		return nil, fmt.Errorf("unable to load SDK config: %w", err)
	}

	client := dynamodb.NewFromConfig(cfg)

	return &DynamoDBClient{
		client:       client,
		mappingTable: mappingTable,
		counterTable: counterTable,
	}, nil
}

// GetNextCounter atomically increments and returns the next counter value
func (db *DynamoDBClient) GetNextCounter(ctx context.Context) (int64, error) {
	input := &dynamodb.UpdateItemInput{
		TableName: aws.String(db.counterTable),
		Key: map[string]types.AttributeValue{
			"counter_id": &types.AttributeValueMemberS{Value: "global"},
		},
		UpdateExpression: aws.String("ADD counter_value :inc"),
		ExpressionAttributeValues: map[string]types.AttributeValue{
			":inc": &types.AttributeValueMemberN{Value: "1"},
		},
		ReturnValues: types.ReturnValueUpdatedNew,
	}

	result, err := db.client.UpdateItem(ctx, input)
	if err != nil {
		return 0, fmt.Errorf("failed to increment counter: %w", err)
	}

	counterValue, ok := result.Attributes["counter_value"].(*types.AttributeValueMemberN)
	if !ok {
		return 0, fmt.Errorf("invalid counter value type")
	}

	value, err := strconv.ParseInt(counterValue.Value, 10, 64)
	if err != nil {
		return 0, fmt.Errorf("failed to parse counter value: %w", err)
	}

	return value, nil
}

// SaveURLMapping saves a URL mapping to DynamoDB
func (db *DynamoDBClient) SaveURLMapping(ctx context.Context, mapping *URLMapping) error {
	input := &dynamodb.PutItemInput{
		TableName: aws.String(db.mappingTable),
		Item: map[string]types.AttributeValue{
			"hash":          &types.AttributeValueMemberS{Value: mapping.Hash},
			"original_url":  &types.AttributeValueMemberS{Value: mapping.OriginalURL},
			"created_at":    &types.AttributeValueMemberN{Value: strconv.FormatInt(mapping.CreatedAt, 10)},
			"click_count":   &types.AttributeValueMemberN{Value: strconv.FormatInt(mapping.ClickCount, 10)},
			"last_accessed": &types.AttributeValueMemberN{Value: strconv.FormatInt(mapping.LastAccessed, 10)},
		},
	}

	_, err := db.client.PutItem(ctx, input)
	if err != nil {
		return fmt.Errorf("failed to save URL mapping: %w", err)
	}

	return nil
}

// GetURLMapping retrieves a URL mapping by hash
func (db *DynamoDBClient) GetURLMapping(ctx context.Context, hash string) (*URLMapping, error) {
	input := &dynamodb.GetItemInput{
		TableName: aws.String(db.mappingTable),
		Key: map[string]types.AttributeValue{
			"hash": &types.AttributeValueMemberS{Value: hash},
		},
	}

	result, err := db.client.GetItem(ctx, input)
	if err != nil {
		return nil, fmt.Errorf("failed to get URL mapping: %w", err)
	}

	if result.Item == nil {
		return nil, nil // Not found
	}

	mapping := &URLMapping{}

	if hash, ok := result.Item["hash"].(*types.AttributeValueMemberS); ok {
		mapping.Hash = hash.Value
	}

	if url, ok := result.Item["original_url"].(*types.AttributeValueMemberS); ok {
		mapping.OriginalURL = url.Value
	}

	if createdAt, ok := result.Item["created_at"].(*types.AttributeValueMemberN); ok {
		mapping.CreatedAt, _ = strconv.ParseInt(createdAt.Value, 10, 64)
	}

	if clickCount, ok := result.Item["click_count"].(*types.AttributeValueMemberN); ok {
		mapping.ClickCount, _ = strconv.ParseInt(clickCount.Value, 10, 64)
	}

	if lastAccessed, ok := result.Item["last_accessed"].(*types.AttributeValueMemberN); ok {
		mapping.LastAccessed, _ = strconv.ParseInt(lastAccessed.Value, 10, 64)
	}

	return mapping, nil
}

// IncrementClickCount atomically increments the click count and updates last accessed time
func (db *DynamoDBClient) IncrementClickCount(ctx context.Context, hash string) error {
	now := time.Now().Unix()

	input := &dynamodb.UpdateItemInput{
		TableName: aws.String(db.mappingTable),
		Key: map[string]types.AttributeValue{
			"hash": &types.AttributeValueMemberS{Value: hash},
		},
		UpdateExpression: aws.String("ADD click_count :inc SET last_accessed = :now"),
		ExpressionAttributeValues: map[string]types.AttributeValue{
			":inc": &types.AttributeValueMemberN{Value: "1"},
			":now": &types.AttributeValueMemberN{Value: strconv.FormatInt(now, 10)},
		},
	}

	_, err := db.client.UpdateItem(ctx, input)
	if err != nil {
		return fmt.Errorf("failed to increment click count: %w", err)
	}

	return nil
}
