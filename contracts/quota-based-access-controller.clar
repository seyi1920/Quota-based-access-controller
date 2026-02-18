;; =====================================================
;; QuotaBasedAccessController
;; Usage-metered access and pay-per-use control
;; =====================================================

;; -----------------------------
;; Data Variables
;; -----------------------------

(define-data-var admin principal tx-sender)
(define-data-var price-per-unit uint u1000000) ;; default 1 STX (microstx)
(define-data-var max-units-per-user uint u1000)

;; -----------------------------
;; Data Maps
;; -----------------------------

;; user => available quota
(define-map user-quotas
  principal
  uint
)

;; -----------------------------
;; Errors
;; -----------------------------

(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-INSUFFICIENT-QUOTA (err u101))
(define-constant ERR-OVER-MAX (err u102))
(define-constant ERR-INVALID-AMOUNT (err u103))

;; -----------------------------
;; Helpers
;; -----------------------------

(define-read-only (is-admin)
  (is-eq tx-sender (var-get admin))
)

;; -----------------------------
;; Configuration
;; -----------------------------

(define-public (set-price (new-price uint))
  (begin
    (asserts! (is-admin) ERR-NOT-AUTHORIZED)
    (asserts! (> new-price u0) ERR-INVALID-AMOUNT)
    (var-set price-per-unit new-price)
    (ok true)
  )
)

(define-public (set-max-units (max-units uint))
  (begin
    (asserts! (is-admin) ERR-NOT-AUTHORIZED)
    (var-set max-units-per-user max-units)
    (ok true)
  )
)

;; -----------------------------
;; Purchase Quota
;; -----------------------------

(define-public (purchase-units (units uint))
  (begin
    (asserts! (> units u0) ERR-INVALID-AMOUNT)

    (let (
      (cost (* units (var-get price-per-unit)))
      (current (default-to u0 (map-get? user-quotas tx-sender)))
      (new-total (+ current units))
    )

      (asserts! (<= new-total (var-get max-units-per-user)) ERR-OVER-MAX)

      ;; FIXED: Added try! to handle the response from stx-transfer?
      ;; This ensures the quota is ONLY updated if the transfer succeeds.
      (try! (stx-transfer? cost tx-sender (as-contract tx-sender)))

      ;; Update quota
      (map-set user-quotas tx-sender new-total)

      (ok new-total)
    )
  )
)

;; -----------------------------
;; Consume Units (Gate Function)
;; -----------------------------

(define-public (consume (units uint))
  (let ((current (default-to u0 (map-get? user-quotas tx-sender))))
    (begin
      (asserts! (>= current units) ERR-INSUFFICIENT-QUOTA)

      (map-set user-quotas tx-sender (- current units))

      (ok true)
    )
  )
)

;; -----------------------------
;; Read-only Views
;; -----------------------------

(define-read-only (get-quota (user principal))
  (default-to u0 (map-get? user-quotas user))
)

(define-read-only (get-price)
  (var-get price-per-unit)
)