# Cars BnB Backend API

Rails 7 JSON API backend for the Cars BnB reservation application.

---

## Setup

**Requirements:** Ruby >= 3.1.2, PostgreSQL

```bash
bundle install
rails db:create db:migrate
rails server
```

---

## Authentication

All endpoints except `GET /cars` (and related car read endpoints) require a valid JWT token.

**Sign up:**
```
POST /users
Body: { "user": { "name": "...", "email": "...", "password": "..." } }
```

**Sign in:**
```
POST /users/sign_in
Body: { "user": { "email": "...", "password": "..." } }
Response Header: Authorization: Bearer <token>
```

Pass the token in subsequent requests:
```
Authorization: Bearer <token>
```

**Sign out:**
```
DELETE /users/sign_out
```

---

## Cars

### `GET /cars`
List all cars. Supports filtering, sorting, and availability-window search.

**Query parameters:**

| Param | Type | Description |
|---|---|---|
| `brand` | string | Filter by brand (e.g. `Toyota`) |
| `model` | string | Filter by model (e.g. `Corolla`) |
| `category` | string | Filter by category (e.g. `sedan`, `suv`) |
| `min_price` | decimal | Minimum price per day |
| `max_price` | decimal | Maximum price per day |
| `start_date` | date (YYYY-MM-DD) | Start of availability window |
| `end_date` | date (YYYY-MM-DD) | End of availability window |
| `sort` | string | One of `price_asc`, `price_desc`, `newest` |

**Example – sedans under $100/day available next week:**
```
GET /cars?category=sedan&max_price=100&start_date=2026-04-20&end_date=2026-04-27&sort=price_asc
```

**Response:**
```json
{
  "code": 200,
  "cars": [...],
  "user": { ... }
}
```

---

### `GET /cars/:id`
Get a single car by ID. Public endpoint.

**Response:**
```json
{ "code": 200, "car": { ... } }
```

---

### `GET /cars/:id/availability?start_date=&end_date=`
Check whether a specific car is available for a date range. Public endpoint.

**Query parameters:** `start_date`, `end_date` (both required, YYYY-MM-DD)

**Response:**
```json
{
  "code": 200,
  "car_id": 1,
  "available": true,
  "start_date": "2026-04-20",
  "end_date": "2026-04-25"
}
```

Returns `422` if `start_date` or `end_date` is missing.

---

### `POST /cars` *(Auth required)*
Create a new car.

**Body:**
```json
{
  "car": {
    "brand": "Toyota",
    "model": "Corolla",
    "year_released": "2021-01-01",
    "featured_image": "https://...",
    "specifications": "...",
    "price_per_day": 50.00,
    "category": "sedan"
  }
}
```

---

### `DELETE /cars/:id` *(Auth required)*
Delete a car.

---

## Reservations

All reservation endpoints require authentication.

### `GET /reservations`
List the current user's reservations.

**Query parameters:**

| Param | Value | Description |
|---|---|---|
| `filter` | `upcoming` | Active reservations with `end_date >= today` |
| `filter` | `past` | Active reservations with `end_date < today` |
| `filter` | `active` | All active (non-cancelled) reservations |
| *(none)* | | All reservations (active + cancelled) |

**Response:**
```json
{ "code": 200, "reservations": [...] }
```

---

### `GET /reservations/:id`
Get detail of a single reservation belonging to the current user.

**Response:**
```json
{ "code": 200, "reservation": { ... } }
```

Returns `404` if the reservation does not belong to the current user.

---

### `POST /reservations`
Create a new reservation.

**Body:**
```json
{
  "reservation": {
    "car_id": 1,
    "city": "Nairobi",
    "start_date": "2026-04-20",
    "end_date": "2026-04-25"
  }
}
```

> **Note:** For backward compatibility, you may also pass `reservation_date` (single-day); it will be used as both `start_date` and `end_date` if those are not provided.

**Conflict detection:** The API rejects the request with `422 Unprocessable Entity` if the car already has an active reservation overlapping the requested date range.

**Validation rules:**
- `city`, `start_date`, `end_date` are required.
- `end_date` must be on or after `start_date`.
- No overlapping active reservations for the same car.

---

### `PATCH /reservations/:id/cancel`
Soft-cancel an active reservation (sets `status: "cancelled"` and records `cancelled_at`).

After cancellation the dates are freed up and the car becomes reservable again for those dates.

**Response:**
```json
{ "code": 200, "reservation": { ... }, "message": "Reservation cancelled" }
```

Returns `404` if the reservation is not found or is already cancelled.

---

### `DELETE /reservations/:id`
Hard-delete a reservation record.

---

## Reservation Data Model

| Field | Type | Description |
|---|---|---|
| `id` | integer | Primary key |
| `car_id` | integer | Foreign key to car |
| `user_id` | integer | Foreign key to user |
| `city` | string | Pickup/drop-off city |
| `start_date` | date | Start date of reservation |
| `end_date` | date | End date of reservation |
| `status` | string | `"active"` or `"cancelled"` |
| `cancelled_at` | datetime | Timestamp of cancellation (nullable) |
| `reservation_date` | date | Legacy single-date field (kept for compat) |

---

## Car Data Model

| Field | Type | Description |
|---|---|---|
| `id` | integer | Primary key |
| `brand` | string | Car brand (e.g. Toyota) |
| `model` | string | Car model (e.g. Corolla) |
| `year_released` | datetime | Year the model was released |
| `featured_image` | string | URL of main image |
| `specifications` | string | Free-text specs |
| `price_per_day` | decimal | Daily rental price |
| `category` | string | Car category (e.g. sedan, suv) |

---

## Frontend Issue Mapping

| Frontend Issue | Backend Support Added |
|---|---|
| [#2 Cars discovery (filters/sort/availability)](https://github.com/bobb-Rob/cars-test-reservation-app-frontend/issues/2) | `GET /cars` query params: `brand`, `model`, `category`, `min_price`, `max_price`, `sort`, `start_date`/`end_date`; `GET /cars/:id/availability` |
| [#3 UI design system](https://github.com/bobb-Rob/cars-test-reservation-app-frontend/issues/3) | No backend changes needed |
| [#4 Modernize styling](https://github.com/bobb-Rob/cars-test-reservation-app-frontend/issues/4) | No backend changes needed |
| [#5 My Reservations + cancel + details](https://github.com/bobb-Rob/cars-test-reservation-app-frontend/issues/5) | `GET /reservations?filter=upcoming\|past`, `GET /reservations/:id`, `PATCH /reservations/:id/cancel` |
| [#6 Availability check + conflict prevention](https://github.com/bobb-Rob/cars-test-reservation-app-frontend/issues/6) | Date-range reservations (`start_date`/`end_date`), conflict validation in `POST /reservations`, `GET /cars/:id/availability` |

---

## Running Tests

```bash
bundle exec rspec
```

