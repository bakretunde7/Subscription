# Subscription - Recurring Payment Management

## Overview

**Subscription** is a decentralized contract for managing recurring payments, service plans, and automated billing. It allows service providers to define subscription plans, while users can subscribe, make payments, and manage access to services.

---

## Features

* Create and manage service plans
* Subscribe to services with automated billing cycles
* Track subscription activity and payments
* Grant and revoke service access dynamically
* Automatic payment tracking with history logs
* Cancel subscriptions or toggle auto-renewal
* Providers can update or deactivate plans

---

## Data Structures

* **service-plans**: Stores service plan details (price, billing cycle, provider, etc.)
* **subscriptions**: Tracks subscriber activity, payments, and renewal settings
* **payment-history**: Records all subscription payments
* **service-access**: Grants or revokes access to services

---

## Key Functions

### Service Plan Management

* `create-service-plan(name, description, price, billing-cycle)` – Create a new plan
* `update-service-plan(plan-id, new-price, new-billing-cycle)` – Update plan pricing and cycle
* `deactivate-service-plan(plan-id)` – Deactivate a plan (provider only)

### Subscriptions

* `subscribe(plan-id)` – Subscribe to a plan
* `make-payment(subscription-id)` – Pay for the next billing cycle
* `cancel-subscription(subscription-id)` – Cancel an active subscription
* `toggle-auto-renew(subscription-id)` – Enable or disable auto-renew

### Read-Only

* `get-service-plan(plan-id)` – Get plan details
* `get-subscription(subscription-id)` – Get subscription info
* `get-payment(subscription-id, payment-id)` – Retrieve payment details
* `has-access(subscriber, plan-id)` – Check if subscriber currently has service access
* `payment-overdue(subscription-id)` – Verify if payment is overdue
* `get-subscription-count()` – Total number of subscriptions

---

## Variables

* **subscription-counter** – Tracks subscription IDs
* **service-counter** – Tracks service plan IDs

---

## Error Codes

* `ERR_UNAUTHORIZED (401)` – Unauthorized action
* `ERR_NOT_FOUND (404)` – Record not found
* `ERR_SUBSCRIPTION_INACTIVE (403)` – Subscription not active
* `ERR_PAYMENT_OVERDUE (405)` – Payment overdue
* `ERR_INVALID_AMOUNT (400)` – Invalid input value
* `ERR_ALREADY_CANCELED (406)` – Subscription already canceled

