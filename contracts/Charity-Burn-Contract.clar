;; Charity Burn Contract
;; Users can "burn" tokens, but the burned value is automatically donated to a charity

;; Contract constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-insufficient-balance (err u101))
(define-constant err-invalid-amount (err u102))
(define-constant err-contract-paused (err u103))
(define-constant err-charity-not-set (err u104))
(define-constant err-min-burn-amount (err u105))
(define-constant err-max-burn-exceeded (err u106))
(define-constant err-charity-same-as-current (err u107))

;; Contract configuration
(define-constant min-burn-amount u1000000) ;; 1 STX minimum
(define-constant max-burn-per-tx u100000000000) ;; 100,000 STX maximum per transaction
(define-constant burn-fee-percentage u100) ;; 1% fee (100 basis points)

;; Data variables
(define-data-var charity-address (optional principal) none)
(define-data-var total-burned uint u0)
(define-data-var total-donated uint u0)
(define-data-var total-fees-collected uint u0)
(define-data-var contract-paused bool false)
(define-data-var charity-count uint u0)

;; Data maps
(define-map user-burn-history principal uint)
(define-map user-burn-count principal uint)
(define-map charity-history principal {total-received: uint, set-at-block: uint})
(define-map daily-burn-stats uint uint) ;; block-height -> amount burned that day
(define-map burn-events uint {burner: principal, amount: uint, charity: principal, block-height: uint, timestamp: uint})

;; Read-only functions
(define-read-only (get-charity-address)
  (var-get charity-address))

(define-read-only (get-total-burned)
  (var-get total-burned))

(define-read-only (get-total-donated)
  (var-get total-donated))

(define-read-only (get-total-fees-collected)
  (var-get total-fees-collected))

(define-read-only (get-contract-paused)
  (var-get contract-paused))

(define-read-only (get-user-burn-amount (user principal))
  (default-to u0 (map-get? user-burn-history user)))

(define-read-only (get-user-burn-count (user principal))
  (default-to u0 (map-get? user-burn-count user)))

(define-read-only (get-charity-history (charity principal))
  (map-get? charity-history charity))

(define-read-only (get-daily-burn-stats (day uint))
  (default-to u0 (map-get? daily-burn-stats day)))

(define-read-only (get-burn-event (event-id uint))
  (map-get? burn-events event-id))

(define-read-only (calculate-fee (amount uint))
  (/ (* amount burn-fee-percentage) u10000))

(define-read-only (get-net-donation (amount uint))
  (- amount (calculate-fee amount)))

(define-read-only (get-contract-stats)
  {
    total-burned: (var-get total-burned),
    total-donated: (var-get total-donated),
    total-fees: (var-get total-fees-collected),
    charity-count: (var-get charity-count),
    current-charity: (var-get charity-address),
    paused: (var-get contract-paused)
  })

;; Private helper functions
(define-private (sum-amounts (amount uint) (acc uint))
  (+ acc amount))

(define-private (record-burn-event (burner principal) (amount uint) (charity principal))
  (let
    (
      (event-id (var-get total-burned))
      (current-day (/ block-height u144)) ;; Approximate daily blocks
    )
    (begin
      ;; Record the burn event
      (map-set burn-events event-id {
        burner: burner,
        amount: amount,
        charity: charity,
        block-height: block-height,
        timestamp: (unwrap-panic (get-block-info? time block-height))
      })

      ;; Update daily stats
      (map-set daily-burn-stats current-day 
        (+ (default-to u0 (map-get? daily-burn-stats current-day)) amount))

      event-id)))

;; Public functions
(define-public (set-charity-address (new-charity principal))
  (let
    (
      (current-charity (var-get charity-address))
    )
    (begin
      (asserts! (is-eq tx-sender contract-owner) err-owner-only)
      (asserts! (not (var-get contract-paused)) err-contract-paused)
      (asserts! (not (is-eq (some new-charity) current-charity)) err-charity-same-as-current)

      ;; Update charity history if there was a previous charity
      (match current-charity
        prev-charity 
          (map-set charity-history prev-charity {
            total-received: (default-to u0 (get total-received (map-get? charity-history prev-charity))),
            set-at-block: block-height
          })
        true)

      ;; Set new charity and increment counter
      (var-set charity-address (some new-charity))
      (var-set charity-count (+ (var-get charity-count) u1))

      (ok new-charity))))

(define-public (pause-contract)
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (var-set contract-paused true)
    (ok true)))

(define-public (unpause-contract)
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (var-set contract-paused false)
    (ok true)))

(define-public (burn-for-charity (amount uint))
  (let
    (
      (sender-balance (stx-get-balance tx-sender))
      (current-burned (default-to u0 (map-get? user-burn-history tx-sender)))
      (current-count (default-to u0 (map-get? user-burn-count tx-sender)))
      (charity (var-get charity-address))
      (fee-amount (calculate-fee amount))
      (net-donation (get-net-donation amount))
    )
    (begin
      ;; Validate contract state
      (asserts! (not (var-get contract-paused)) err-contract-paused)
      (asserts! (is-some charity) err-charity-not-set)

      ;; Validate amount
      (asserts! (>= amount min-burn-amount) err-min-burn-amount)
      (asserts! (<= amount max-burn-per-tx) err-max-burn-exceeded)
      (asserts! (>= sender-balance amount) err-insufficient-balance)

      ;; Transfer net donation to charity
      (try! (stx-transfer? net-donation tx-sender (unwrap-panic charity)))

      ;; Transfer fee to contract owner (if any)
      (if (> fee-amount u0)
        (try! (stx-transfer? fee-amount tx-sender contract-owner))
        true)

      ;; Update state variables
      (var-set total-burned (+ (var-get total-burned) amount))
      (var-set total-donated (+ (var-get total-donated) net-donation))
      (var-set total-fees-collected (+ (var-get total-fees-collected) fee-amount))

      ;; Update user history
      (map-set user-burn-history tx-sender (+ current-burned amount))
      (map-set user-burn-count tx-sender (+ current-count u1))

      ;; Update charity history
      (match charity
        charity-addr
          (map-set charity-history charity-addr {
            total-received: (+ net-donation (default-to u0 (get total-received (map-get? charity-history charity-addr)))),
            set-at-block: block-height
          })
        false)

      ;; Record the burn event
      (let ((event-id (record-burn-event tx-sender amount (unwrap-panic charity))))
        ;; Return success with comprehensive burn details
        (ok {
          event-id: event-id,
          amount: amount,
          net-donation: net-donation,
          fee: fee-amount,
          charity: (unwrap-panic charity),
          user-total-burned: (+ current-burned amount),
          user-burn-count: (+ current-count u1),
          contract-total-burned: (var-get total-burned)
        })))))

(define-public (emergency-pause)
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (var-set contract-paused true)
    (ok "Contract emergency paused")))

(define-public (withdraw-fees (amount uint))
  (let
    (
      (available-fees (var-get total-fees-collected))
    )
    (begin
      (asserts! (is-eq tx-sender contract-owner) err-owner-only)
      (asserts! (<= amount available-fees) err-insufficient-balance)

      (try! (stx-transfer? amount (as-contract tx-sender) contract-owner))
      (var-set total-fees-collected (- available-fees amount))

      (ok amount))))

(define-public (burn-for-charity-with-message (amount uint) (message (string-ascii 280)))
  (let
    (
      (burn-result (try! (burn-for-charity amount)))
    )
    (begin
      (print {
        event: "charity-burn-with-message",
        burner: tx-sender,
        amount: amount,
        message: message,
        charity: (unwrap-panic (var-get charity-address))
      })
      (ok (merge burn-result {message: message})))))

(define-public (batch-burn-for-charity (amounts (list 10 uint)))
  (let
    (
      (total-amount (fold sum-amounts amounts u0))
      (sender-balance (stx-get-balance tx-sender))
      (charity (var-get charity-address))
    )
    (begin
      (asserts! (not (var-get contract-paused)) err-contract-paused)
      (asserts! (is-some charity) err-charity-not-set)
      (asserts! (>= sender-balance total-amount) err-insufficient-balance)

      ;; Process the total batch amount as a single burn
      (burn-for-charity total-amount)
    )))

(define-public (get-user-impact-report (user principal))
  (ok {
    total-burned: (get-user-burn-amount user),
    burn-count: (get-user-burn-count user),
    estimated-charity-impact: (get-net-donation (get-user-burn-amount user)),
    rank: (calculate-user-rank user)
  }))

(define-read-only (calculate-user-rank (user principal))
  u1) ;; Simplified rank calculation

(define-public (transfer-ownership (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (ok new-owner)))

;; Contract initialization
(begin
  (var-set charity-address none)
  (var-set contract-paused false))