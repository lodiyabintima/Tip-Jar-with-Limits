(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-insufficient-amount (err u101))
(define-constant err-daily-limit-exceeded (err u102))
(define-constant err-invalid-amount (err u103))
(define-constant err-withdrawal-failed (err u104))
(define-constant err-tip-failed (err u105))
(define-constant err-refund-window-expired (err u106))
(define-constant err-tip-not-found (err u107))
(define-constant err-refund-failed (err u108))
(define-constant err-execution-too-early (err u109))
(define-constant err-schedule-not-found (err u110))
(define-constant err-invalid-execution-block (err u111))
(define-constant err-matching-inactive (err u112))
(define-constant err-matching-budget-exceeded (err u113))

(define-data-var daily-tip-limit uint u1000000)
(define-data-var total-tips-received uint u0)
(define-data-var contract-active bool true)

(define-map user-daily-tips 
  { user: principal, day: uint } 
  { amount: uint })

(define-map user-total-tips 
  principal 
  { total: uint, last-tip-block: uint })

(define-map user-limit-overrides 
  principal 
  uint)

(define-map daily-totals 
  uint 
  { total-amount: uint, tip-count: uint })

(define-map user-milestones 
  principal 
  { milestone-level: uint, multiplier-uses: uint })

(define-data-var milestone-1 uint u5000000)
(define-data-var milestone-2 uint u10000000)
(define-data-var milestone-3 uint u25000000)

(define-data-var refund-window uint u10)
(define-data-var next-tip-id uint u1)
(define-data-var next-schedule-id uint u1)

(define-map refundable-tips 
  { user: principal, tip-id: uint } 
  { amount: uint, block-height: uint, day: uint, is-multiplied: bool })

(define-map scheduled-tips 
  { user: principal, schedule-id: uint } 
  { amount: uint, execution-block: uint, use-multiplier: bool })

(define-data-var matching-active bool false)
(define-data-var matching-rate uint u50)
(define-data-var matching-budget uint u0)
(define-data-var total-matched uint u0)

(define-map user-matched-totals 
  principal 
  { total-matched: uint, match-count: uint })

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
        (limit (get-effective-daily-limit user)))
    (if (>= current-tips limit)
      u0
      (- limit current-tips))))

(define-read-only (get-user-total-tips (user principal))
  (default-to 
    { total: u0, last-tip-block: u0 }
    (map-get? user-total-tips user)))

(define-read-only (get-effective-daily-limit (user principal))
  (let ((override (default-to u0 (map-get? user-limit-overrides user))))
    (if (> override u0) override (var-get daily-tip-limit))))

(define-read-only (get-user-daily-limit (user principal))
  (get-effective-daily-limit user))

(define-read-only (get-daily-stats (day uint))
  (default-to 
    { total-amount: u0, tip-count: u0 }
    (map-get? daily-totals day)))

(define-read-only (get-current-day-stats)
  (get-daily-stats (get-current-day)))

(define-read-only (get-user-milestone (user principal))
  (default-to 
    { milestone-level: u0, multiplier-uses: u0 }
    (map-get? user-milestones user)))

(define-read-only (calculate-milestone-level (total-tips uint))
  (if (>= total-tips (var-get milestone-3))
    u3
    (if (>= total-tips (var-get milestone-2))
      u2
      (if (>= total-tips (var-get milestone-1))
        u1
        u0))))

(define-read-only (get-milestone-multiplier (level uint))
  (if (is-eq level u3)
    u3
    (if (is-eq level u2)
      u2
      (if (is-eq level u1)
        u150
        u100))))

(define-read-only (has-available-multiplier (user principal))
  (let ((milestone-data (get-user-milestone user)))
    (> (get multiplier-uses milestone-data) u0)))

(define-read-only (get-refund-window)
  (var-get refund-window))

(define-read-only (is-refund-eligible (user principal) (tip-id uint))
  (let ((tip-data (map-get? refundable-tips { user: user, tip-id: tip-id })))
    (match tip-data
      some-tip (let ((tip-block (get block-height some-tip))
                     (current-block stacks-block-height)
                     (window (var-get refund-window)))
                 (<= (- current-block tip-block) window))
      false)))

(define-read-only (get-refundable-tip (user principal) (tip-id uint))
  (map-get? refundable-tips { user: user, tip-id: tip-id }))

(define-read-only (get-scheduled-tip (user principal) (schedule-id uint))
  (map-get? scheduled-tips { user: user, schedule-id: schedule-id }))

(define-read-only (is-execution-ready (user principal) (schedule-id uint))
  (let ((schedule-data (map-get? scheduled-tips { user: user, schedule-id: schedule-id })))
    (match schedule-data
      some-schedule (>= stacks-block-height (get execution-block some-schedule))
      false)))

(define-read-only (get-matching-status)
  { 
    active: (var-get matching-active),
    rate: (var-get matching-rate),
    budget: (var-get matching-budget),
    total-matched: (var-get total-matched),
    remaining-budget: (- (var-get matching-budget) (var-get total-matched))
  })

(define-read-only (get-user-matched-stats (user principal))
  (default-to 
    { total-matched: u0, match-count: u0 }
    (map-get? user-matched-totals user)))

(define-read-only (calculate-match-amount (tip-amount uint))
  (let ((rate (var-get matching-rate)))
    (/ (* tip-amount rate) u100)))

(define-public (send-tip (amount uint))
  (let ((current-day (get-current-day))
        (user-key { user: tx-sender, day: current-day })
        (current-user-tips (get amount (get-user-daily-tips tx-sender)))
        (new-total (+ current-user-tips amount))
        (daily-limit (get-effective-daily-limit tx-sender))
        (user-stats (get-user-total-tips tx-sender))
        (current-day-stats (get-daily-stats current-day)))
    
    (asserts! (var-get contract-active) err-insufficient-amount)
    (asserts! (> amount u0) err-invalid-amount)
    (asserts! (<= new-total daily-limit) err-daily-limit-exceeded)
    
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    
    (map-set user-daily-tips 
      user-key 
      { amount: new-total })
    
    (let ((new-total-tips (+ (get total user-stats) amount)))
      (map-set user-total-tips 
        tx-sender 
        { 
          total: new-total-tips,
          last-tip-block: stacks-block-height 
        })
      
      (let ((current-milestone (get-user-milestone tx-sender))
            (new-level (calculate-milestone-level new-total-tips))
            (current-level (get milestone-level current-milestone)))
        (if (> new-level current-level)
          (map-set user-milestones 
            tx-sender 
            { 
              milestone-level: new-level, 
              multiplier-uses: (if (is-eq new-level u1) u1 (if (is-eq new-level u2) u2 u3))
            })
          true))
      
      (map-set daily-totals 
        current-day 
        { 
          total-amount: (+ (get total-amount current-day-stats) amount),
          tip-count: (+ (get tip-count current-day-stats) u1)
        })
      
      (var-set total-tips-received (+ (var-get total-tips-received) amount)))
    
    (let ((tip-id (var-get next-tip-id))
          (matching-enabled (var-get matching-active))
          (match-amount (if matching-enabled (calculate-match-amount amount) u0))
          (budget (var-get matching-budget))
          (already-matched (var-get total-matched))
          (can-match (and matching-enabled (<= (+ already-matched match-amount) budget)))
          (final-match (if can-match match-amount u0)))
      
      (map-set refundable-tips 
        { user: tx-sender, tip-id: tip-id }
        { 
          amount: amount, 
          block-height: stacks-block-height, 
          day: current-day, 
          is-multiplied: false 
        })
      (var-set next-tip-id (+ tip-id u1))
      
      (if (> final-match u0)
        (begin
          (var-set total-matched (+ already-matched final-match))
          (let ((user-match-stats (get-user-matched-stats tx-sender)))
            (map-set user-matched-totals 
              tx-sender 
              { 
                total-matched: (+ (get total-matched user-match-stats) final-match),
                match-count: (+ (get match-count user-match-stats) u1)
              }))
          true)
        true)
      
      (ok { 
        amount: amount, 
        new-daily-total: new-total, 
        remaining-limit: (- daily-limit new-total),
        day: current-day,
        tip-id: tip-id,
        matched-amount: final-match
      }))))

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
        (daily-limit (get-effective-daily-limit user)))
    (and 
      (var-get contract-active)
      (> amount u0)
      (<= (+ current-tips amount) daily-limit))))

(define-public (use-milestone-multiplier (amount uint))
  (let ((current-day (get-current-day))
        (user-key { user: tx-sender, day: current-day })
        (current-user-tips (get amount (get-user-daily-tips tx-sender)))
        (milestone-data (get-user-milestone tx-sender))
        (multiplier (get-milestone-multiplier (get milestone-level milestone-data)))
        (boosted-amount (/ (* amount multiplier) u100))
        (new-total (+ current-user-tips boosted-amount))
        (daily-limit (get-effective-daily-limit tx-sender))
        (user-stats (get-user-total-tips tx-sender))
        (current-day-stats (get-daily-stats current-day)))
    
    (asserts! (var-get contract-active) err-insufficient-amount)
    (asserts! (> amount u0) err-invalid-amount)
    (asserts! (> (get multiplier-uses milestone-data) u0) err-invalid-amount)
    (asserts! (<= new-total daily-limit) err-daily-limit-exceeded)
    
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    
    (map-set user-daily-tips 
      user-key 
      { amount: new-total })
    
    (map-set user-milestones 
      tx-sender 
      { 
        milestone-level: (get milestone-level milestone-data),
        multiplier-uses: (- (get multiplier-uses milestone-data) u1)
      })
    
    (let ((new-total-tips (+ (get total user-stats) boosted-amount)))
      (map-set user-total-tips 
        tx-sender 
        { 
          total: new-total-tips,
          last-tip-block: stacks-block-height 
        })
      
      (map-set daily-totals 
        current-day 
        { 
          total-amount: (+ (get total-amount current-day-stats) boosted-amount),
          tip-count: (+ (get tip-count current-day-stats) u1)
        })
      
      (var-set total-tips-received (+ (var-get total-tips-received) boosted-amount)))
    
    (let ((tip-id (var-get next-tip-id)))
      (map-set refundable-tips 
        { user: tx-sender, tip-id: tip-id }
        { 
          amount: boosted-amount, 
          block-height: stacks-block-height, 
          day: current-day, 
          is-multiplied: true 
        })
      (var-set next-tip-id (+ tip-id u1))
      
      (ok { 
        original-amount: amount,
        boosted-amount: boosted-amount, 
        multiplier: multiplier,
        new-daily-total: new-total, 
        remaining-limit: (- daily-limit new-total),
        remaining-uses: (- (get multiplier-uses milestone-data) u1),
        tip-id: tip-id
      }))))

(define-read-only (get-tip-history-summary (user principal))
  (let ((daily-tips (get-user-daily-tips user))
        (total-tips (get-user-total-tips user))
        (remaining (get-user-remaining-limit user))
        (milestone-data (get-user-milestone user)))
    {
      today-tips: (get amount daily-tips),
      total-tips: (get total total-tips),
      remaining-today: remaining,
      last-tip-block: (get last-tip-block total-tips),
      current-day: (get-current-day),
      milestone-level: (get milestone-level milestone-data),
      multiplier-uses: (get multiplier-uses milestone-data)
    }))

(define-public (refund-tip (tip-id uint))
  (let ((tip-key { user: tx-sender, tip-id: tip-id })
        (tip-data (unwrap! (map-get? refundable-tips tip-key) err-tip-not-found)))
    
    (asserts! (is-refund-eligible tx-sender tip-id) err-refund-window-expired)
    
    (let ((refund-amount (get amount tip-data))
          (tip-day (get day tip-data))
          (is-multiplied (get is-multiplied tip-data))
          (user-key { user: tx-sender, day: tip-day })
          (current-user-daily (get amount (default-to { amount: u0 } (map-get? user-daily-tips user-key))))
          (user-stats (get-user-total-tips tx-sender))
          (day-stats (get-daily-stats tip-day)))
      
      (try! (as-contract (stx-transfer? refund-amount tx-sender tx-sender)))
      
      (map-set user-daily-tips 
        user-key 
        { amount: (- current-user-daily refund-amount) })
      
      (map-set user-total-tips 
        tx-sender 
        { 
          total: (- (get total user-stats) refund-amount),
          last-tip-block: (get last-tip-block user-stats)
        })
      
      (map-set daily-totals 
        tip-day 
        { 
          total-amount: (- (get total-amount day-stats) refund-amount),
          tip-count: (- (get tip-count day-stats) u1)
        })
      
      (var-set total-tips-received (- (var-get total-tips-received) refund-amount))
      
      (if is-multiplied
        (let ((current-milestone (get-user-milestone tx-sender)))
          (map-set user-milestones 
            tx-sender 
            { 
              milestone-level: (get milestone-level current-milestone),
              multiplier-uses: (+ (get multiplier-uses current-milestone) u1)
            }))
        true)
      
      (map-delete refundable-tips tip-key)
      
      (ok { 
        refunded-amount: refund-amount,
        tip-id: tip-id,
        was-multiplied: is-multiplied
      }))))

(define-public (schedule-tip (amount uint) (execution-block uint) (use-multiplier bool))
  (begin
    (asserts! (var-get contract-active) err-insufficient-amount)
    (asserts! (> amount u0) err-invalid-amount)
    (asserts! (> execution-block stacks-block-height) err-invalid-execution-block)
    
    (if use-multiplier
      (asserts! (has-available-multiplier tx-sender) err-invalid-amount)
      true)
    
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    
    (let ((schedule-id (var-get next-schedule-id)))
      (map-set scheduled-tips 
        { user: tx-sender, schedule-id: schedule-id }
        { 
          amount: amount, 
          execution-block: execution-block, 
          use-multiplier: use-multiplier 
        })
      (var-set next-schedule-id (+ schedule-id u1))
      
      (ok { 
        schedule-id: schedule-id,
        amount: amount,
        execution-block: execution-block,
        blocks-until-execution: (- execution-block stacks-block-height)
      }))))

(define-public (execute-scheduled-tip (schedule-id uint))
  (let ((schedule-key { user: tx-sender, schedule-id: schedule-id })
        (schedule-data (unwrap! (map-get? scheduled-tips schedule-key) err-schedule-not-found)))
    
    (asserts! (>= stacks-block-height (get execution-block schedule-data)) err-execution-too-early)
    
    (let ((amount (get amount schedule-data))
          (use-multiplier (get use-multiplier schedule-data)))
      
      (map-delete scheduled-tips schedule-key)
      
      (if use-multiplier
        (match (use-milestone-multiplier amount)
          success (ok { 
            executed-amount: amount,
            schedule-id: schedule-id,
            used-multiplier: true
          })
          error (err error))
        (match (send-tip amount)
          success (ok { 
            executed-amount: amount,
            schedule-id: schedule-id,
            used-multiplier: false
          })
          error (err error))))))

(define-public (cancel-scheduled-tip (schedule-id uint))
  (let ((schedule-key { user: tx-sender, schedule-id: schedule-id })
        (schedule-data (unwrap! (map-get? scheduled-tips schedule-key) err-schedule-not-found)))
    
    (try! (as-contract (stx-transfer? (get amount schedule-data) tx-sender tx-sender)))
    
    (map-delete scheduled-tips schedule-key)
    
    (ok { 
      refunded-amount: (get amount schedule-data),
      schedule-id: schedule-id
    })))

(define-public (activate-matching-program (budget uint) (rate uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (> budget u0) err-invalid-amount)
    (asserts! (<= rate u100) err-invalid-amount)
    
    (var-set matching-active true)
    (var-set matching-budget budget)
    (var-set matching-rate rate)
    (var-set total-matched u0)
    
    (ok { 
      budget: budget,
      rate: rate
    })))

(define-public (deactivate-matching-program)
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    
    (var-set matching-active false)
    
    (ok { 
      final-matched: (var-get total-matched),
      final-budget: (var-get matching-budget)
    })))

(define-public (update-matching-budget (additional-budget uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (> additional-budget u0) err-invalid-amount)
    
    (var-set matching-budget (+ (var-get matching-budget) additional-budget))
    
    (ok { 
      new-budget: (var-get matching-budget)
    })))

(define-public (update-matching-rate (new-rate uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (<= new-rate u100) err-invalid-amount)
    
    (var-set matching-rate new-rate)
    
    (ok { 
      new-rate: new-rate
    })))

(define-public (set-user-daily-limit (user principal) (new-limit uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (> new-limit u0) err-invalid-amount)
    (map-set user-limit-overrides user new-limit)
    (ok new-limit)))

(define-public (clear-user-daily-limit (user principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (map-delete user-limit-overrides user)
    (ok true)))
