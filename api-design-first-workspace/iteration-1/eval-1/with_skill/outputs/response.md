# E-Commerce Product Catalog API

## Overview

RESTful API for managing product categories, products, and customer reviews. Follows API-first design principles with OpenAPI 3.0 as the source of truth.

- **Base URL**: `https://api.example.com/v1`
- **Content Type**: `application/json`
- **Versioning**: URL path (`/v1/`)

---

## Resources

### Categories

Hierarchical product categories with optional parent-child relationships (max depth: 3).

**Endpoints:**

| Method | Path | Description |
|--------|------|-------------|
| GET | `/categories` | List all categories |
| POST | `/categories` | Create a category |
| GET | `/categories/{id}` | Get a category |
| PUT | `/categories/{id}` | Full update |
| PATCH | `/categories/{id}` | Partial update |
| DELETE | `/categories/{id}` | Delete a category |
| GET | `/categories/{id}/products` | Products in category |

**Query Parameters (list):**

- `parent_id` — Filter by parent category
- `include_children` — Include nested subcategories (boolean, default: false)
- `page` — Page number (default: 1)
- `per_page` — Items per page (default: 20, max: 100)
- `sort` — Sort field (e.g., `name`, `-name`, `created_at`)

---

### Products

Products belong to exactly one category and have images, pricing, and inventory status.

**Endpoints:**

| Method | Path | Description |
|--------|------|-------------|
| GET | `/products` | List products |
| POST | `/products` | Create a product |
| GET | `/products/{id}` | Get a product |
| PUT | `/products/{id}` | Full update |
| PATCH | `/products/{id}` | Partial update |
| DELETE | `/products/{id}` | Delete a product |
| GET | `/products/{id}/reviews` | Reviews for product |

**Query Parameters (list):**

- `category_id` — Filter by category
- `status` — Filter by status (`active`, `draft`, `archived`)
- `price_gte` / `price_lte` — Price range filtering
- `in_stock` — Only in-stock products (boolean)
- `search` — Full-text search on name/description
- `page` — Page number (default: 1)
- `per_page` — Items per page (default: 20, max: 100)
- `sort` — Sort field (e.g., `price`, `-price`, `created_at`, `rating`)

---

### Reviews

Customer reviews attached to products. Each review belongs to one product and has an author, rating, and optional text.

**Endpoints:**

| Method | Path | Description |
|--------|------|-------------|
| GET | `/reviews` | List all reviews |
| POST | `/reviews` | Create a review |
| GET | `/reviews/{id}` | Get a review |
| PUT | `/reviews/{id}` | Full update |
| PATCH | `/reviews/{id}` | Partial update |
| DELETE | `/reviews/{id}` | Delete a review |

**Query Parameters (list):**

- `product_id` — Filter by product
- `rating_gte` / `rating_lte` — Rating range
- `page` — Page number (default: 1)
- `per_page` — Items per page (default: 20, max: 100)
- `sort` — Sort field (e.g., `-created_at`, `-rating`)

---

## OpenAPI 3.0 Specification

```yaml
openapi: 3.0.3
info:
  title: E-Commerce Product Catalog API
  description: RESTful API for managing product categories, products, and reviews.
  version: 1.0.0
  contact:
    name: API Support
    email: api@example.com

servers:
  - url: https://api.example.com/v1
    description: Production
  - url: https://staging-api.example.com/v1
    description: Staging

tags:
  - name: Categories
    description: Product category management
  - name: Products
    description: Product catalog management
  - name: Reviews
    description: Product review management

paths:
  /categories:
    get:
      tags: [Categories]
      summary: List categories
      operationId: listCategories
      parameters:
        - $ref: '#/components/parameters/PageParam'
        - $ref: '#/components/parameters/PerPageParam'
        - $ref: '#/components/parameters/SortParam'
        - name: parent_id
          in: query
          description: Filter by parent category ID
          schema:
            type: string
        - name: include_children
          in: query
          description: Include nested subcategories
          schema:
            type: boolean
            default: false
      responses:
        '200':
          description: Success
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/CategoryList'
        '401':
          $ref: '#/components/responses/Unauthorized'

    post:
      tags: [Categories]
      summary: Create a category
      operationId: createCategory
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/CategoryCreate'
      responses:
        '201':
          description: Created
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Category'
        '400':
          $ref: '#/components/responses/BadRequest'
        '409':
          description: Duplicate category name
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Error'

  /categories/{id}:
    parameters:
      - $ref: '#/components/parameters/IdParam'

    get:
      tags: [Categories]
      summary: Get category
      operationId: getCategory
      responses:
        '200':
          description: Success
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Category'
        '404':
          $ref: '#/components/responses/NotFound'

    put:
      tags: [Categories]
      summary: Update category (full)
      operationId: updateCategory
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/CategoryUpdate'
      responses:
        '200':
          description: Updated
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Category'
        '400':
          $ref: '#/components/responses/BadRequest'
        '404':
          $ref: '#/components/responses/NotFound'

    patch:
      tags: [Categories]
      summary: Update category (partial)
      operationId: patchCategory
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/CategoryPatch'
      responses:
        '200':
          description: Updated
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Category'
        '404':
          $ref: '#/components/responses/NotFound'

    delete:
      tags: [Categories]
      summary: Delete category
      operationId: deleteCategory
      responses:
        '204':
          description: Deleted
        '404':
          $ref: '#/components/responses/NotFound'
        '409':
          description: Category has products or subcategories
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Error'

  /categories/{id}/products:
    parameters:
      - $ref: '#/components/parameters/IdParam'

    get:
      tags: [Categories]
      summary: List products in category
      operationId: listCategoryProducts
      parameters:
        - $ref: '#/components/parameters/PageParam'
        - $ref: '#/components/parameters/PerPageParam'
        - $ref: '#/components/parameters/SortParam'
      responses:
        '200':
          description: Success
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/ProductList'
        '404':
          $ref: '#/components/responses/NotFound'

  /products:
    get:
      tags: [Products]
      summary: List products
      operationId: listProducts
      parameters:
        - $ref: '#/components/parameters/PageParam'
        - $ref: '#/components/parameters/PerPageParam'
        - $ref: '#/components/parameters/SortParam'
        - name: category_id
          in: query
          description: Filter by category
          schema:
            type: string
        - name: status
          in: query
          description: Filter by status
          schema:
            type: string
            enum: [active, draft, archived]
        - name: price_gte
          in: query
          description: Minimum price
          schema:
            type: number
            format: float
        - name: price_lte
          in: query
          description: Maximum price
          schema:
            type: number
            format: float
        - name: in_stock
          in: query
          description: Only in-stock products
          schema:
            type: boolean
        - name: search
          in: query
          description: Full-text search
          schema:
            type: string
      responses:
        '200':
          description: Success
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/ProductList'

    post:
      tags: [Products]
      summary: Create a product
      operationId: createProduct
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/ProductCreate'
      responses:
        '201':
          description: Created
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Product'
        '400':
          $ref: '#/components/responses/BadRequest'

  /products/{id}:
    parameters:
      - $ref: '#/components/parameters/IdParam'

    get:
      tags: [Products]
      summary: Get product
      operationId: getProduct
      responses:
        '200':
          description: Success
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Product'
        '404':
          $ref: '#/components/responses/NotFound'

    put:
      tags: [Products]
      summary: Update product (full)
      operationId: updateProduct
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/ProductUpdate'
      responses:
        '200':
          description: Updated
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Product'
        '400':
          $ref: '#/components/responses/BadRequest'
        '404':
          $ref: '#/components/responses/NotFound'

    patch:
      tags: [Products]
      summary: Update product (partial)
      operationId: patchProduct
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/ProductPatch'
      responses:
        '200':
          description: Updated
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Product'
        '404':
          $ref: '#/components/responses/NotFound'

    delete:
      tags: [Products]
      summary: Delete product
      operationId: deleteProduct
      responses:
        '204':
          description: Deleted
        '404':
          $ref: '#/components/responses/NotFound'

  /products/{id}/reviews:
    parameters:
      - $ref: '#/components/parameters/IdParam'

    get:
      tags: [Products]
      summary: List reviews for product
      operationId: listProductReviews
      parameters:
        - $ref: '#/components/parameters/PageParam'
        - $ref: '#/components/parameters/PerPageParam'
        - $ref: '#/components/parameters/SortParam'
      responses:
        '200':
          description: Success
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/ReviewList'
        '404':
          $ref: '#/components/responses/NotFound'

  /reviews:
    get:
      tags: [Reviews]
      summary: List all reviews
      operationId: listReviews
      parameters:
        - $ref: '#/components/parameters/PageParam'
        - $ref: '#/components/parameters/PerPageParam'
        - $ref: '#/components/parameters/SortParam'
        - name: product_id
          in: query
          description: Filter by product
          schema:
            type: string
        - name: rating_gte
          in: query
          description: Minimum rating
          schema:
            type: integer
            minimum: 1
            maximum: 5
        - name: rating_lte
          in: query
          description: Maximum rating
          schema:
            type: integer
            minimum: 1
            maximum: 5
      responses:
        '200':
          description: Success
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/ReviewList'

    post:
      tags: [Reviews]
      summary: Create a review
      operationId: createReview
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/ReviewCreate'
      responses:
        '201':
          description: Created
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Review'
        '400':
          $ref: '#/components/responses/BadRequest'

  /reviews/{id}:
    parameters:
      - $ref: '#/components/parameters/IdParam'

    get:
      tags: [Reviews]
      summary: Get review
      operationId: getReview
      responses:
        '200':
          description: Success
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Review'
        '404':
          $ref: '#/components/responses/NotFound'

    put:
      tags: [Reviews]
      summary: Update review (full)
      operationId: updateReview
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/ReviewUpdate'
      responses:
        '200':
          description: Updated
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Review'
        '400':
          $ref: '#/components/responses/BadRequest'
        '404':
          $ref: '#/components/responses/NotFound'

    patch:
      tags: [Reviews]
      summary: Update review (partial)
      operationId: patchReview
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/ReviewPatch'
      responses:
        '200':
          description: Updated
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Review'
        '404':
          $ref: '#/components/responses/NotFound'

    delete:
      tags: [Reviews]
      summary: Delete review
      operationId: deleteReview
      responses:
        '204':
          description: Deleted
        '404':
          $ref: '#/components/responses/NotFound'

components:
  parameters:
    IdParam:
      name: id
      in: path
      required: true
      schema:
        type: string

    PageParam:
      name: page
      in: query
      description: Page number
      schema:
        type: integer
        default: 1
        minimum: 1

    PerPageParam:
      name: per_page
      in: query
      description: Items per page
      schema:
        type: integer
        default: 20
        minimum: 1
        maximum: 100

    SortParam:
      name: sort
      in: query
      description: "Sort field (prefix with - for descending)"
      schema:
        type: string
        example: "-created_at"

  schemas:
    Category:
      type: object
      required: [id, name, slug]
      properties:
        id:
          type: string
          example: "cat-electronics"
        name:
          type: string
          example: "Electronics"
        slug:
          type: string
          example: "electronics"
        description:
          type: string
          example: "Electronic devices and accessories"
        parent_id:
          type: string
          nullable: true
          example: null
        display_order:
          type: integer
          example: 1
        is_active:
          type: boolean
          example: true
        product_count:
          type: integer
          description: Number of products in this category
          example: 42
        created_at:
          type: string
          format: date-time
        updated_at:
          type: string
          format: date-time

    CategoryCreate:
      type: object
      required: [name, slug]
      properties:
        name:
          type: string
          minLength: 1
          maxLength: 100
        slug:
          type: string
          pattern: "^[a-z0-9-]+$"
          minLength: 1
          maxLength: 100
        description:
          type: string
          maxLength: 500
        parent_id:
          type: string
          nullable: true
        display_order:
          type: integer
          default: 0

    CategoryUpdate:
      type: object
      required: [name, slug]
      properties:
        name:
          type: string
          minLength: 1
          maxLength: 100
        slug:
          type: string
          pattern: "^[a-z0-9-]+$"
        description:
          type: string
          maxLength: 500
        parent_id:
          type: string
          nullable: true
        display_order:
          type: integer
        is_active:
          type: boolean

    CategoryPatch:
      type: object
      properties:
        name:
          type: string
          minLength: 1
          maxLength: 100
        slug:
          type: string
          pattern: "^[a-z0-9-]+$"
        description:
          type: string
          maxLength: 500
        parent_id:
          type: string
          nullable: true
        display_order:
          type: integer
        is_active:
          type: boolean

    CategoryList:
      type: object
      properties:
        data:
          type: array
          items:
            $ref: '#/components/schemas/Category'
        meta:
          $ref: '#/components/schemas/PaginationMeta'

    Product:
      type: object
      required: [id, name, slug, category_id, price, status]
      properties:
        id:
          type: string
          example: "prod-wireless-headphones"
        name:
          type: string
          example: "Wireless Headphones"
        slug:
          type: string
          example: "wireless-headphones"
        description:
          type: string
          example: "Premium noise-cancelling wireless headphones"
        category_id:
          type: string
          example: "cat-electronics"
        sku:
          type: string
          example: "WH-1000XM5"
        price:
          type: number
          format: float
          example: 349.99
        compare_at_price:
          type: number
          format: float
          nullable: true
          description: Original price before discount
          example: 399.99
        currency:
          type: string
          default: "USD"
          example: "USD"
        images:
          type: array
          items:
            $ref: '#/components/schemas/ProductImage'
        stock_quantity:
          type: integer
          example: 125
        is_active:
          type: boolean
          example: true
        average_rating:
          type: number
          format: float
          readOnly: true
          example: 4.7
        review_count:
          type: integer
          readOnly: true
          example: 238
        tags:
          type: array
          items:
            type: string
          example: ["wireless", "noise-cancelling", "bluetooth"]
        created_at:
          type: string
          format: date-time
        updated_at:
          type: string
          format: date-time

    ProductCreate:
      type: object
      required: [name, slug, category_id, price]
      properties:
        name:
          type: string
          minLength: 1
          maxLength: 200
        slug:
          type: string
          pattern: "^[a-z0-9-]+$"
        description:
          type: string
          maxLength: 5000
        category_id:
          type: string
        sku:
          type: string
          maxLength: 100
        price:
          type: number
          format: float
          minimum: 0
        compare_at_price:
          type: number
          format: float
          nullable: true
          minimum: 0
        currency:
          type: string
          default: "USD"
        images:
          type: array
          items:
            $ref: '#/components/schemas/ProductImageCreate'
          maxItems: 10
        stock_quantity:
          type: integer
          default: 0
          minimum: 0
        is_active:
          type: boolean
          default: true
        tags:
          type: array
          items:
            type: string
          maxItems: 20

    ProductUpdate:
      type: object
      required: [name, slug, category_id, price]
      properties:
        name:
          type: string
          minLength: 1
          maxLength: 200
        slug:
          type: string
          pattern: "^[a-z0-9-]+$"
        description:
          type: string
          maxLength: 5000
        category_id:
          type: string
        sku:
          type: string
          maxLength: 100
        price:
          type: number
          format: float
          minimum: 0
        compare_at_price:
          type: number
          format: float
          nullable: true
        currency:
          type: string
        images:
          type: array
          items:
            $ref: '#/components/schemas/ProductImageCreate'
          maxItems: 10
        stock_quantity:
          type: integer
          minimum: 0
        is_active:
          type: boolean
        tags:
          type: array
          items:
            type: string

    ProductPatch:
      type: object
      properties:
        name:
          type: string
          minLength: 1
          maxLength: 200
        description:
          type: string
          maxLength: 5000
        category_id:
          type: string
        price:
          type: number
          format: float
          minimum: 0
        compare_at_price:
          type: number
          format: float
          nullable: true
        stock_quantity:
          type: integer
          minimum: 0
        is_active:
          type: boolean
        tags:
          type: array
          items:
            type: string

    ProductList:
      type: object
      properties:
        data:
          type: array
          items:
            $ref: '#/components/schemas/Product'
        meta:
          $ref: '#/components/schemas/PaginationMeta'

    ProductImage:
      type: object
      properties:
        url:
          type: string
          format: uri
          example: "https://cdn.example.com/products/wh-1000xm5.jpg"
        alt_text:
          type: string
          example: "Wireless headphones front view"
        is_primary:
          type: boolean
          example: true
        display_order:
          type: integer
          example: 0

    ProductImageCreate:
      type: object
      required: [url]
      properties:
        url:
          type: string
          format: uri
        alt_text:
          type: string
        is_primary:
          type: boolean
          default: false
        display_order:
          type: integer
          default: 0

    Review:
      type: object
      required: [id, product_id, author_name, rating]
      properties:
        id:
          type: string
          example: "rev-abc123"
        product_id:
          type: string
          example: "prod-wireless-headphones"
        author_name:
          type: string
          example: "Jane Smith"
        rating:
          type: integer
          minimum: 1
          maximum: 5
          example: 5
        title:
          type: string
          example: "Best headphones I've owned"
        body:
          type: string
          example: "Amazing noise cancellation and comfort."
        verified_purchase:
          type: boolean
          readOnly: true
          example: true
        helpful_count:
          type: integer
          readOnly: true
          example: 12
        created_at:
          type: string
          format: date-time
        updated_at:
          type: string
          format: date-time

    ReviewCreate:
      type: object
      required: [product_id, author_name, rating]
      properties:
        product_id:
          type: string
        author_name:
          type: string
          minLength: 1
          maxLength: 100
        rating:
          type: integer
          minimum: 1
          maximum: 5
        title:
          type: string
          maxLength: 200
        body:
          type: string
          maxLength: 5000

    ReviewUpdate:
      type: object
      required: [author_name, rating]
      properties:
        author_name:
          type: string
          minLength: 1
          maxLength: 100
        rating:
          type: integer
          minimum: 1
          maximum: 5
        title:
          type: string
          maxLength: 200
        body:
          type: string
          maxLength: 5000

    ReviewPatch:
      type: object
      properties:
        author_name:
          type: string
          minLength: 1
          maxLength: 100
        rating:
          type: integer
          minimum: 1
          maximum: 5
        title:
          type: string
          maxLength: 200
        body:
          type: string
          maxLength: 5000

    ReviewList:
      type: object
      properties:
        data:
          type: array
          items:
            $ref: '#/components/schemas/Review'
        meta:
          $ref: '#/components/schemas/PaginationMeta'

    PaginationMeta:
      type: object
      properties:
        page:
          type: integer
        per_page:
          type: integer
        total:
          type: integer
        total_pages:
          type: integer

    Error:
      type: object
      properties:
        error:
          type: object
          required: [code, message]
          properties:
            code:
              type: string
              description: Machine-readable error code
              example: "VALIDATION_ERROR"
            message:
              type: string
              description: Human-readable error message
              example: "Request validation failed"
            details:
              type: array
              items:
                type: object
                properties:
                  field:
                    type: string
                    example: "price"
                  message:
                    type: string
                    example: "Must be greater than 0"

  responses:
    BadRequest:
      description: Bad request (validation error)
      content:
        application/json:
          schema:
            $ref: '#/components/schemas/Error'
          example:
            error:
              code: "VALIDATION_ERROR"
              message: "Request validation failed"
              details:
                - field: "price"
                  message: "Must be greater than 0"

    Unauthorized:
      description: Authentication required
      content:
        application/json:
          schema:
            $ref: '#/components/schemas/Error'
          example:
            error:
              code: "AUTHENTICATION_REQUIRED"
              message: "Valid authentication token required"

    NotFound:
      description: Resource not found
      content:
        application/json:
          schema:
            $ref: '#/components/schemas/Error'
          example:
            error:
              code: "RESOURCE_NOT_FOUND"
              message: "The requested resource does not exist"

  securitySchemes:
    bearerAuth:
      type: http
      scheme: bearer
      bearerFormat: JWT

security:
  - bearerAuth: []
```

---

## Usage Examples

### List products with filtering and pagination

```bash
GET /v1/products?category_id=cat-electronics&price_lte=500&in_stock=true&sort=-rating&page=1&per_page=20
```

### Create a product

```bash
POST /v1/products
Content-Type: application/json

{
  "name": "Wireless Charger",
  "slug": "wireless-charger",
  "category_id": "cat-electronics",
  "price": 29.99,
  "sku": "WC-001",
  "stock_quantity": 200,
  "tags": ["wireless", "charging"]
}
```

### Create a review

```bash
POST /v1/reviews
Content-Type: application/json

{
  "product_id": "prod-wireless-headphones",
  "author_name": "Jane Smith",
  "rating": 5,
  "title": "Excellent quality",
  "body": "Best purchase this year."
}
```

### Full update

```bash
PUT /v1/products/prod-wireless-headphones
Content-Type: application/json

{
  "name": "Wireless Headphones Pro",
  "slug": "wireless-headphones-pro",
  "category_id": "cat-electronics",
  "price": 399.99
}
```

---

## Status Code Reference

| Code | Usage |
|------|-------|
| 200 | Successful GET, PUT, PATCH |
| 201 | Successful POST (resource created) |
| 204 | Successful DELETE |
| 400 | Bad request (validation error) |
| 401 | Unauthorized |
| 404 | Resource not found |
| 409 | Conflict (duplicate slug, category has children) |
| 422 | Unprocessable entity |
| 429 | Rate limited |
| 500 | Server error |
