# E-Commerce Product Catalog REST API Design

## Base URL
```
https://api.example.com/v1
```

## Authentication
- JWT Bearer token in `Authorization` header
- Public endpoints (browse products) require no auth
- Protected endpoints (create/update/delete) require authenticated user
- Admin endpoints require `admin` role

---

## Data Models

### Category
```json
{
  "id": "uuid",
  "name": "string",
  "slug": "string",
  "description": "string|null",
  "parent_id": "uuid|null",
  "image_url": "string|null",
  "is_active": "boolean",
  "sort_order": "integer",
  "created_at": "ISO8601",
  "updated_at": "ISO8601"
}
```

### Product
```json
{
  "id": "uuid",
  "name": "string",
  "slug": "string",
  "description": "string",
  "short_description": "string|null",
  "sku": "string",
  "price": "decimal",
  "compare_at_price": "decimal|null",
  "currency": "string",
  "category_id": "uuid",
  "brand": "string|null",
  "weight": "decimal|null",
  "weight_unit": "string|null",
  "images": ["string"],
  "attributes": {},
  "is_active": "boolean",
  "stock_quantity": "integer",
  "average_rating": "decimal",
  "review_count": "integer",
  "created_at": "ISO8601",
  "updated_at": "ISO8601"
}
```

### Review
```json
{
  "id": "uuid",
  "product_id": "uuid",
  "user_id": "uuid",
  "user_name": "string",
  "rating": "integer (1-5)",
  "title": "string",
  "body": "string",
  "images": ["string"],
  "is_verified_purchase": "boolean",
  "helpful_count": "integer",
  "created_at": "ISO8601",
  "updated_at": "ISO8601"
}
```

---

## Endpoints

### Categories

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/categories` | List all categories (tree structure) |
| `GET` | `/categories/{id}` | Get category by ID |
| `GET` | `/categories/slug/{slug}` | Get category by slug |
| `POST` | `/categories` | Create category (admin) |
| `PUT` | `/categories/{id}` | Update category (admin) |
| `DELETE` | `/categories/{id}` | Delete category (admin) |

#### Query Parameters for `GET /categories`
- `parent_id` (optional) - Filter by parent category
- `is_active` (optional) - Filter by active status
- `include_children` (boolean, default: true) - Include subcategories

#### POST /categories - Request Body
```json
{
  "name": "Electronics",
  "description": "Electronic devices and accessories",
  "parent_id": null,
  "image_url": "https://cdn.example.com/cat/electronics.jpg",
  "is_active": true,
  "sort_order": 1
}
```

#### Response: `201 Created`
```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "name": "Electronics",
  "slug": "electronics",
  "description": "Electronic devices and accessories",
  "parent_id": null,
  "image_url": "https://cdn.example.com/cat/electronics.jpg",
  "is_active": true,
  "sort_order": 1,
  "created_at": "2025-01-15T10:30:00Z",
  "updated_at": "2025-01-15T10:30:00Z"
}
```

---

### Products

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/products` | List products with filtering/pagination |
| `GET` | `/products/{id}` | Get product by ID |
| `GET` | `/products/slug/{slug}` | Get product by slug |
| `GET` | `/categories/{category_id}/products` | List products in category |
| `POST` | `/products` | Create product (admin) |
| `PUT` | `/products/{id}` | Update product (admin) |
| `DELETE` | `/products/{id}` | Delete product (admin) |
| `PATCH` | `/products/{id}/stock` | Update stock quantity (admin) |

#### Query Parameters for `GET /products`
- `page` (integer, default: 1) - Page number
- `per_page` (integer, default: 20, max: 100) - Items per page
- `category_id` (optional) - Filter by category
- `brand` (optional) - Filter by brand
- `min_price` (optional) - Minimum price filter
- `max_price` (optional) - Maximum price filter
- `is_active` (optional) - Filter by active status
- `search` (optional) - Full-text search in name/description
- `sort` (optional) - Sort field: `name`, `price`, `created_at`, `average_rating`
- `order` (optional) - Sort direction: `asc` (default), `desc`
- `attributes` (optional) - JSON object for custom attribute filtering

#### Example Request
```
GET /products?category_id=550e8400&min_price=10&max_price=100&sort=price&order=asc&page=1&per_page=10
```

#### Response: `200 OK`
```json
{
  "data": [
    {
      "id": "660e8400-e29b-41d4-a716-446655440000",
      "name": "Wireless Bluetooth Headphones",
      "slug": "wireless-bluetooth-headphones",
      "description": "High-quality wireless headphones with noise cancellation",
      "short_description": "Premium wireless headphones",
      "sku": "WBH-001",
      "price": 79.99,
      "compare_at_price": 99.99,
      "currency": "USD",
      "category_id": "550e8400-e29b-41d4-a716-446655440000",
      "brand": "AudioTech",
      "images": [
        "https://cdn.example.com/products/wbh-001-front.jpg",
        "https://cdn.example.com/products/wbh-001-side.jpg"
      ],
      "attributes": {
        "color": "black",
        "connectivity": "bluetooth-5.0",
        "battery_life": "30 hours"
      },
      "is_active": true,
      "stock_quantity": 150,
      "average_rating": 4.5,
      "review_count": 128,
      "created_at": "2025-01-10T08:00:00Z",
      "updated_at": "2025-01-15T12:00:00Z"
    }
  ],
  "pagination": {
    "current_page": 1,
    "per_page": 10,
    "total_items": 42,
    "total_pages": 5
  }
}
```

#### POST /products - Request Body
```json
{
  "name": "Wireless Bluetooth Headphones",
  "description": "High-quality wireless headphones with noise cancellation",
  "short_description": "Premium wireless headphones",
  "sku": "WBH-001",
  "price": 79.99,
  "compare_at_price": 99.99,
  "currency": "USD",
  "category_id": "550e8400-e29b-41d4-a716-446655440000",
  "brand": "AudioTech",
  "weight": 0.25,
  "weight_unit": "kg",
  "images": [
    "https://cdn.example.com/products/wbh-001-front.jpg"
  ],
  "attributes": {
    "color": "black",
    "connectivity": "bluetooth-5.0"
  },
  "is_active": true,
  "stock_quantity": 100
}
```

#### PATCH /products/{id}/stock - Request Body
```json
{
  "quantity": 150,
  "operation": "set"
}
```
Valid `operation` values: `set`, `increment`, `decrement`

---

### Reviews

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/products/{product_id}/reviews` | List reviews for product |
| `GET` | `/reviews/{id}` | Get review by ID |
| `POST` | `/products/{product_id}/reviews` | Create review (authenticated) |
| `PUT` | `/reviews/{id}` | Update own review |
| `DELETE` | `/reviews/{id}` | Delete own review or admin |
| `POST` | `/reviews/{id}/helpful` | Mark review as helpful (authenticated) |

#### Query Parameters for `GET /products/{product_id}/reviews`
- `page` (integer, default: 1)
- `per_page` (integer, default: 10, max: 50)
- `rating` (optional) - Filter by rating (1-5)
- `sort` (optional) - `created_at`, `rating`, `helpful_count`
- `order` (optional) - `asc`, `desc` (default: desc for created_at)

#### Response: `200 OK`
```json
{
  "data": [
    {
      "id": "770e8400-e29b-41d4-a716-446655440000",
      "product_id": "660e8400-e29b-41d4-a716-446655440000",
      "user_id": "880e8400-e29b-41d4-a716-446655440000",
      "user_name": "John D.",
      "rating": 5,
      "title": "Excellent sound quality",
      "body": "These headphones exceeded my expectations. The noise cancellation is superb and the battery lasts all day.",
      "images": [],
      "is_verified_purchase": true,
      "helpful_count": 24,
      "created_at": "2025-01-12T14:30:00Z",
      "updated_at": "2025-01-12T14:30:00Z"
    }
  ],
  "pagination": {
    "current_page": 1,
    "per_page": 10,
    "total_items": 128,
    "total_pages": 13
  },
  "summary": {
    "average_rating": 4.5,
    "rating_distribution": {
      "5": 64,
      "4": 38,
      "3": 18,
      "2": 5,
      "1": 3
    }
  }
}
```

#### POST /products/{product_id}/reviews - Request Body
```json
{
  "rating": 5,
  "title": "Excellent sound quality",
  "body": "These headphones exceeded my expectations.",
  "images": []
}
```

#### Response: `201 Created`
Returns created review object.

---

## Error Responses

### Standard Error Format
```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Request validation failed",
    "details": [
      {
        "field": "price",
        "message": "Price must be greater than 0"
      }
    ]
  }
}
```

### HTTP Status Codes
- `200` - Success
- `201` - Created
- `204` - No Content (successful delete)
- `400` - Bad Request (validation error)
- `401` - Unauthorized (missing/invalid token)
- `403` - Forbidden (insufficient permissions)
- `404` - Not Found
- `409` - Conflict (duplicate SKU, etc.)
- `422` - Unprocessable Entity (business logic error)
- `429` - Too Many Requests (rate limit)
- `500` - Internal Server Error

### Common Error Codes
| Code | Description |
|------|-------------|
| `VALIDATION_ERROR` | Request body validation failed |
| `NOT_FOUND` | Resource not found |
| `UNAUTHORIZED` | Authentication required |
| `FORBIDDEN` | Insufficient permissions |
| `DUPLICATE_SKU` | Product SKU already exists |
| `DUPLICATE_SLUG` | Slug already in use |
| `CATEGORY_HAS_PRODUCTS` | Cannot delete category with products |
| `PRODUCT_NOT_IN_CATEGORY` | Product doesn't belong to category |
| `RATE_LIMIT_EXCEEDED` | Too many requests |

---

## Filtering & Search

### Product Search
Full-text search across `name`, `description`, `sku`, and `brand` fields.

Example:
```
GET /products?search=wireless+headphones
```

### Attribute Filtering
Products support custom attributes. Filter using JSON object:
```
GET /products?attributes={"color":"black","connectivity":"bluetooth-5.0"}
```

### Price Range
```
GET /products?min_price=25&max_price=100
```

---

## Pagination

All list endpoints support cursor-based or offset pagination.

### Offset Pagination (default)
```
GET /products?page=2&per_page=20
```

### Response Pagination Object
```json
{
  "current_page": 2,
  "per_page": 20,
  "total_items": 150,
  "total_pages": 8,
  "has_next": true,
  "has_previous": true
}
```

---

## Rate Limiting

- **Public endpoints**: 100 requests per minute per IP
- **Authenticated endpoints**: 1000 requests per minute per user
- **Admin endpoints**: 500 requests per minute per user

Rate limit headers included in responses:
```
X-RateLimit-Limit: 1000
X-RateLimit-Remaining: 999
X-RateLimit-Reset: 1705312800
```

---

## Versioning

API version is included in the URL path: `/v1/`

Breaking changes will result in a new version (`/v2/`). Non-breaking additions (new fields, new endpoints) are added to the current version.

---

## Webhooks (Optional)

For real-time notifications:
- `product.created`
- `product.updated`
- `product.deleted`
- `review.created`
- `review.updated`
- `review.deleted`
- `stock.low` (when stock falls below threshold)

---

## Example Workflows

### Browse Products by Category
```
1. GET /categories - Get category tree
2. GET /categories/{id} - Get category details
3. GET /categories/{id}/products?sort=price&order=asc - List products
4. GET /products/{id} - Get product details
5. GET /products/{id}/reviews?sort=helpful_count&order=desc - Get reviews
```

### Admin: Add New Product
```
1. POST /categories - Create category (if needed)
2. POST /products - Create product with category_id
3. PUT /products/{id} - Update product if needed
4. PATCH /products/{id}/stock - Set initial stock
```

### Customer: Leave Review
```
1. POST /auth/login - Authenticate
2. POST /products/{id}/reviews - Submit review
3. POST /reviews/{id}/helpful - Other users mark as helpful
```
