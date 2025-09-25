;; Subscription - Recurring Payment Management
;; Manage subscriptions, billing cycles, and service access

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u401))
(define-constant ERR_NOT_FOUND (err u404))
(define-constant ERR_SUBSCRIPTION_INACTIVE (err u403))
(define-constant ERR_PAYMENT_OVERDUE (err u405))
(define-constant ERR_INVALID_AMOUNT (err u400))
(define-constant ERR_ALREADY_CANCELED (err u406))

;; Variables
(define-data-var subscription-counter uint u0)
(define-data-var service-counter uint u0)

;; Service plans
(define-map service-plans
    { plan-id: uint }
    {
        provider: principal,
        name: (string-utf8 50),
        description: (string-utf8 200),
        price: uint,
        billing-cycle: uint, ;; blocks between payments
        is-active: bool,
        subscriber-count: uint
    }
)

;; Subscriptions
(define-map subscriptions
    { subscription-id: uint }
    {
        subscriber: principal,
        plan-id: uint,
        start-block: uint,
        last-payment-block: uint,
        next-payment-due: uint,
        total-payments: uint,
        total-paid: uint,
        is-active: bool,
        auto-renew: bool
    }
)

;; Payment history
(define-map payment-history
    { subscription-id: uint, payment-id: uint }
    {
        amount: uint,
        payment-block: uint,
        period-start: uint,
        period-end: uint
    }
)

;; Service access
(define-map service-access
    { subscriber: principal, plan-id: uint }
    {
        access-granted: bool,
        access-expires: uint,
        subscription-id: uint
    }
)

;; Read-only functions
(define-read-only (get-service-plan (plan-id uint))
    (map-get? service-plans { plan-id: plan-id })
)

(define-read-only (get-subscription (subscription-id uint))
    (map-get? subscriptions { subscription-id: subscription-id })
)

(define-read-only (get-payment (subscription-id uint) (payment-id uint))
    (map-get? payment-history { subscription-id: subscription-id, payment-id: payment-id })
)

(define-read-only (has-access (subscriber principal) (plan-id uint))
    (match (map-get? service-access { subscriber: subscriber, plan-id: plan-id })
        access (and
            (get access-granted access)
            (>= (get access-expires access) stacks-block-height)
        )
        false
    )
)

(define-read-only (payment-overdue (subscription-id uint))
    (match (get-subscription subscription-id)
        subscription (and
            (get is-active subscription)
            (> stacks-block-height (get next-payment-due subscription))
        )
        false
    )
)

(define-read-only (get-subscription-count)
    (var-get subscription-counter)
)

;; Public functions
(define-public (create-service-plan 
    (name (string-utf8 50))
    (description (string-utf8 200))
    (price uint)
    (billing-cycle uint))
    (let (
        (plan-id (+ (var-get service-counter) u1))
    )
        (asserts! (> price u0) ERR_INVALID_AMOUNT)
        (asserts! (> billing-cycle u0) ERR_INVALID_AMOUNT)
        
        (map-set service-plans
            { plan-id: plan-id }
            {
                provider: tx-sender,
                name: name,
                description: description,
                price: price,
                billing-cycle: billing-cycle,
                is-active: true,
                subscriber-count: u0
            }
        )
        
        (var-set service-counter plan-id)
        (ok plan-id)
    )
)

(define-public (subscribe (plan-id uint))
    (let (
        (plan (unwrap! (get-service-plan plan-id) ERR_NOT_FOUND))
        (subscription-id (+ (var-get subscription-counter) u1))
        (current-block stacks-block-height)
        (next-payment (+ current-block (get billing-cycle plan)))
        (access-expires (+ current-block (get billing-cycle plan)))
    )
        (asserts! (get is-active plan) ERR_SUBSCRIPTION_INACTIVE)
        
        ;; Create subscription
        (map-set subscriptions
            { subscription-id: subscription-id }
            {
                subscriber: tx-sender,
                plan-id: plan-id,
                start-block: current-block,
                last-payment-block: current-block,
                next-payment-due: next-payment,
                total-payments: u1,
                total-paid: (get price plan),
                is-active: true,
                auto-renew: true
            }
        )
        
        ;; Grant service access
        (map-set service-access
            { subscriber: tx-sender, plan-id: plan-id }
            {
                access-granted: true,
                access-expires: access-expires,
                subscription-id: subscription-id
            }
        )
        
        ;; Update plan subscriber count
        (map-set service-plans
            { plan-id: plan-id }
            (merge plan { subscriber-count: (+ (get subscriber-count plan) u1) })
        )
        
        ;; Record first payment
        (map-set payment-history
            { subscription-id: subscription-id, payment-id: u1 }
            {
                amount: (get price plan),
                payment-block: current-block,
                period-start: current-block,
                period-end: access-expires
            }
        )
        
        (var-set subscription-counter subscription-id)
        (ok subscription-id)
    )
)

(define-public (make-payment (subscription-id uint))
    (let (
        (subscription (unwrap! (get-subscription subscription-id) ERR_NOT_FOUND))
        (plan (unwrap! (get-service-plan (get plan-id subscription)) ERR_NOT_FOUND))
        (payment-id (+ (get total-payments subscription) u1))
        (current-block stacks-block-height)
        (next-payment (+ current-block (get billing-cycle plan)))
        (access-expires (+ current-block (get billing-cycle plan)))
    )
        (asserts! (is-eq tx-sender (get subscriber subscription)) ERR_UNAUTHORIZED)
        (asserts! (get is-active subscription) ERR_SUBSCRIPTION_INACTIVE)
        (asserts! (>= current-block (get next-payment-due subscription)) ERR_PAYMENT_OVERDUE)
        
        ;; Update subscription
        (map-set subscriptions
            { subscription-id: subscription-id }
            (merge subscription {
                last-payment-block: current-block,
                next-payment-due: next-payment,
                total-payments: payment-id,
                total-paid: (+ (get total-paid subscription) (get price plan))
            })
        )
        
        ;; Update service access
        (map-set service-access
            { subscriber: tx-sender, plan-id: (get plan-id subscription) }
            {
                access-granted: true,
                access-expires: access-expires,
                subscription-id: subscription-id
            }
        )
        
        ;; Record payment
        (map-set payment-history
            { subscription-id: subscription-id, payment-id: payment-id }
            {
                amount: (get price plan),
                payment-block: current-block,
                period-start: current-block,
                period-end: access-expires
            }
        )
        
        (ok (get price plan))
    )
)

(define-public (cancel-subscription (subscription-id uint))
    (let (
        (subscription (unwrap! (get-subscription subscription-id) ERR_NOT_FOUND))
        (plan (unwrap! (get-service-plan (get plan-id subscription)) ERR_NOT_FOUND))
    )
        (asserts! (is-eq tx-sender (get subscriber subscription)) ERR_UNAUTHORIZED)
        (asserts! (get is-active subscription) ERR_ALREADY_CANCELED)
        
        ;; Deactivate subscription
        (map-set subscriptions
            { subscription-id: subscription-id }
            (merge subscription { is-active: false, auto-renew: false })
        )
        
        ;; Revoke service access
        (map-set service-access
            { subscriber: tx-sender, plan-id: (get plan-id subscription) }
            {
                access-granted: false,
                access-expires: stacks-block-height,
                subscription-id: subscription-id
            }
        )
        
        ;; Update plan subscriber count
        (map-set service-plans
            { plan-id: (get plan-id subscription) }
            (merge plan { subscriber-count: (- (get subscriber-count plan) u1) })
        )
        
        (ok true)
    )
)

(define-public (toggle-auto-renew (subscription-id uint))
    (let (
        (subscription (unwrap! (get-subscription subscription-id) ERR_NOT_FOUND))
    )
        (asserts! (is-eq tx-sender (get subscriber subscription)) ERR_UNAUTHORIZED)
        (asserts! (get is-active subscription) ERR_SUBSCRIPTION_INACTIVE)
        
        (map-set subscriptions
            { subscription-id: subscription-id }
            (merge subscription { auto-renew: (not (get auto-renew subscription)) })
        )
        
        (ok (not (get auto-renew subscription)))
    )
)

(define-public (update-service-plan 
    (plan-id uint) 
    (new-price uint) 
    (new-billing-cycle uint))
    (let (
        (plan (unwrap! (get-service-plan plan-id) ERR_NOT_FOUND))
    )
        (asserts! (is-eq tx-sender (get provider plan)) ERR_UNAUTHORIZED)
        (asserts! (> new-price u0) ERR_INVALID_AMOUNT)
        (asserts! (> new-billing-cycle u0) ERR_INVALID_AMOUNT)
        
        (map-set service-plans
            { plan-id: plan-id }
            (merge plan { 
                price: new-price,
                billing-cycle: new-billing-cycle
            })
        )
        
        (ok true)
    )
)

(define-public (deactivate-service-plan (plan-id uint))
    (let (
        (plan (unwrap! (get-service-plan plan-id) ERR_NOT_FOUND))
    )
        (asserts! (is-eq tx-sender (get provider plan)) ERR_UNAUTHORIZED)
        
        (map-set service-plans
            { plan-id: plan-id }
            (merge plan { is-active: false })
        )
        
        (ok true)
    )
)