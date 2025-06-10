(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-insufficient-amount (err u101))
(define-constant err-daily-limit-exceeded (err u102))
(define-constant err-invalid-amount (err u103))
(define-constant err-withdrawal-failed (err u104))
(define-constant err-tip-failed (err u105))

(define-data-var daily-tip-limit uint u1000000)
(define-data-var total-tips-received uint u0)
(define-data-var contract-active bool true)

(define-map user-daily-tips 
  { user: principal, day: uint } 
  { amount: uint })

(define-map user-total-tips 
  principal 
  { total: uint, last-tip-block: uint })

(define-map daily-totals 
  uint 
  { total-amount: uint, tip-count: uint })

(define-read-only (get-contract-balance)
  (stx-get-balance (as-contract tx-sender)))

(define-read-only (get-daily-limit)
  (var-get daily-tip-limit))

(define-read-only (get-total-tips)
  (var-get total-tips-received))

(define-read-only (get-contract-status)
  (var-get contract-active))

(define-read-only (get-current-day)
  (/ stacks-block-height u144))

(define-read-only (get-user-daily-tips (user principal))
  (let ((current-day (get-current-day)))
    (default-to 
      { amount: u0 }
      (map-get? user-daily-tips { user: user, day: current-day }))))

(define-read-only (get-user-remaining-limit (user principal))
  (let ((current-tips (get amount (get-user-daily-tips user)))
        (limit (var-get daily-tip-limit)))
    (if (>= current-tips limit)
      u0
      (- limit current-tips))))

(define-read-only (get-user-total-tips (user principal))
  (default-to 
    { total: u0, last-tip-block: u0 }
    (map-get? user-total-tips user)))

(define-read-only (get-daily-stats (day uint))
  (default-to 
    { total-amount: u0, tip-count: u0 }
    (map-get? daily-totals day)))

(define-read-only (get-current-day-stats)
  (get-daily-stats (get-current-day)))

(define-public (send-tip (amount uint))
  (let ((current-day (get-current-day))
        (user-key { user: tx-sender, day: current-day })
        (current-user-tips (get amount (get-user-daily-tips tx-sender)))
        (new-total (+ current-user-tips amount))
        (daily-limit (var-get daily-tip-limit))
        (user-stats (get-user-total-tips tx-sender))
        (current-day-stats (get-daily-stats current-day)))
    
    (asserts! (var-get contract-active) err-insufficient-amount)
    (asserts! (> amount u0) err-invalid-amount)
    (asserts! (<= new-total daily-limit) err-daily-limit-exceeded)
    
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    
    (map-set user-daily-tips 
      user-key 
      { amount: new-total })
    
    (map-set user-total-tips 
      tx-sender 
      { 
        total: (+ (get total user-stats) amount),
        last-tip-block: stacks-block-height 
      })
    
    (map-set daily-totals 
      current-day 
      { 
        total-amount: (+ (get total-amount current-day-stats) amount),
        tip-count: (+ (get tip-count current-day-stats) u1)
      })
    
    (var-set total-tips-received (+ (var-get total-tips-received) amount))
    
    (ok { 
      amount: amount, 
      new-daily-total: new-total, 
      remaining-limit: (- daily-limit new-total),
      day: current-day 
    })))

;; (define-public (withdraw-tips (amount uint))
;;   (begin
;;     (asserts! (is-eq tx-sender contract-owner) err-owner-only)
;;     (asserts! (> amount u0) err-invalid-amount)
;;     (asserts! (<= amount (get-contract-balance)) err-insufficient-amount)
    
;;     (let ((transfer-result (as-contract (stx-transfer? amount tx-sender contract-owner))))
;;       (if (is-ok transfer-result)
;;         (ok amount)
;;         (err err-withdrawal-failed)))))

;; (define-public (withdraw-all-tips)
;;   (let ((balance (get-contract-balance)))
;;     (begin
;;       (asserts! (is-eq tx-sender contract-owner) err-owner-only)
;;       (asserts! (> balance u0) err-insufficient-amount)
      
;;       (match (as-contract (stx-transfer? balance tx-sender contract-owner))
;;         success (ok balance)
;;         error (err err-withdrawal-failed)))))

(define-public (set-daily-limit (new-limit uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (> new-limit u0) err-invalid-amount)
    (var-set daily-tip-limit new-limit)
    (ok new-limit)))

(define-public (toggle-contract-status)
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (var-set contract-active (not (var-get contract-active)))
    (ok (var-get contract-active))))

(define-public (emergency-pause)
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (var-set contract-active false)
    (ok true)))

(define-public (resume-contract)
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (var-set contract-active true)
    (ok true)))

(define-read-only (can-tip? (user principal) (amount uint))
  (let ((current-tips (get amount (get-user-daily-tips user)))
        (daily-limit (var-get daily-tip-limit)))
    (and 
      (var-get contract-active)
      (> amount u0)
      (<= (+ current-tips amount) daily-limit))))

(define-read-only (get-tip-history-summary (user principal))
  (let ((daily-tips (get-user-daily-tips user))
        (total-tips (get-user-total-tips user))
        (remaining (get-user-remaining-limit user)))
    {
      today-tips: (get amount daily-tips),
      total-tips: (get total total-tips),
      remaining-today: remaining,
      last-tip-block: (get last-tip-block total-tips),
      current-day: (get-current-day)
    }))