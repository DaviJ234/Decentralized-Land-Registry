;; title: Decentralized Land Registry
;; version: 1.0.0
;; summary: Immutable property records on blockchain to prevent land disputes
;; description: A decentralized land registry system that stores property ownership and transfer history on the Stacks blockchain

;; constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u401))
(define-constant ERR_PROPERTY_NOT_FOUND (err u404))
(define-constant ERR_PROPERTY_EXISTS (err u409))
(define-constant ERR_INVALID_OWNER (err u403))
(define-constant ERR_INVALID_TRANSFER (err u400))
(define-constant ERR_REGISTRAR_NOT_FOUND (err u405))
(define-constant ERR_ALREADY_REGISTERED (err u406))
(define-constant ERR_INVALID_VALUATION (err u407))
(define-constant ERR_VALUATION_EXISTS (err u408))

;; data vars
(define-data-var next-property-id uint u1)
(define-data-var contract-admin principal CONTRACT_OWNER)

;; data maps
(define-map properties 
  uint 
  {
    owner: principal,
    location: (string-ascii 256),
    size: uint,
    property-type: (string-ascii 64),
    value: uint,
    registered-at: uint,
    last-updated: uint,
    verified: bool
  })

(define-map property-transfers
  {property-id: uint, transfer-id: uint}
  {
    from: principal,
    to: principal,
    transfer-date: uint,
    transfer-value: uint,
    transfer-type: (string-ascii 32)
  })

(define-map property-transfer-count uint uint)

(define-map owner-properties principal (list 100 uint))

(define-map authorized-registrars principal bool)

(define-map property-disputes
  uint
  {
    plaintiff: principal,
    defendant: principal,
    dispute-reason: (string-ascii 512),
    filed-at: uint,
    resolved: bool,
    resolution: (optional (string-ascii 512))
  })

(define-map property-valuations
  {property-id: uint, valuation-id: uint}
  {
    appraiser: principal,
    valuation-amount: uint,
    valuation-date: uint,
    valuation-type: (string-ascii 32),
    market-conditions: (string-ascii 128),
    confidence-score: uint
  })

(define-map property-valuation-count uint uint)

(define-map property-value-history
  uint
  {
    current-value: uint,
    previous-value: uint,
    value-change-percentage: int,
    last-valuation-date: uint,
    total-valuations: uint
  })

;; public functions

(define-public (register-property 
  (location (string-ascii 256))
  (size uint)
  (property-type (string-ascii 64))
  (value uint))
  (let 
    (
      (property-id (var-get next-property-id))
      (current-block burn-block-height)
    )
    (asserts! (is-authorized-registrar tx-sender) ERR_UNAUTHORIZED)
    (map-set properties property-id
      {
        owner: tx-sender,
        location: location,
        size: size,
        property-type: property-type,
        value: value,
        registered-at: current-block,
        last-updated: current-block,
        verified: false
      })
    (map-set property-transfer-count property-id u0)
    (map-set property-valuation-count property-id u0)
    (map-set property-value-history property-id
      {
        current-value: value,
        previous-value: u0,
        value-change-percentage: 0,
        last-valuation-date: current-block,
        total-valuations: u0
      })
    (update-owner-properties tx-sender property-id true)
    (var-set next-property-id (+ property-id u1))
    (ok property-id)))

(define-public (transfer-property 
  (property-id uint)
  (new-owner principal)
  (transfer-value uint)
  (transfer-type (string-ascii 32)))
  (let 
    (
      (property (unwrap! (map-get? properties property-id) ERR_PROPERTY_NOT_FOUND))
      (current-owner (get owner property))
      (transfer-count (default-to u0 (map-get? property-transfer-count property-id)))
      (current-block burn-block-height)
    )
    (asserts! (is-eq tx-sender current-owner) ERR_INVALID_OWNER)
    (asserts! (not (is-eq current-owner new-owner)) ERR_INVALID_TRANSFER)
    
    (map-set properties property-id
      (merge property {
        owner: new-owner,
        last-updated: current-block,
        value: transfer-value
      }))
    
    (map-set property-transfers 
      {property-id: property-id, transfer-id: transfer-count}
      {
        from: current-owner,
        to: new-owner,
        transfer-date: current-block,
        transfer-value: transfer-value,
        transfer-type: transfer-type
      })
    
    (map-set property-transfer-count property-id (+ transfer-count u1))
    (update-property-value-history property-id transfer-value)
    (update-owner-properties current-owner property-id false)
    (update-owner-properties new-owner property-id true)
    (ok true)))

(define-public (verify-property (property-id uint))
  (let 
    (
      (property (unwrap! (map-get? properties property-id) ERR_PROPERTY_NOT_FOUND))
    )
    (asserts! (is-authorized-registrar tx-sender) ERR_UNAUTHORIZED)
    (map-set properties property-id
      (merge property {verified: true, last-updated: burn-block-height}))
    (ok true)))

(define-public (add-registrar (registrar principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-admin)) ERR_UNAUTHORIZED)
    (map-set authorized-registrars registrar true)
    (ok true)))

(define-public (remove-registrar (registrar principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-admin)) ERR_UNAUTHORIZED)
    (map-delete authorized-registrars registrar)
    (ok true)))

(define-public (file-dispute 
  (property-id uint)
  (defendant principal)
  (reason (string-ascii 512)))
  (let 
    (
      (property (unwrap! (map-get? properties property-id) ERR_PROPERTY_NOT_FOUND))
      (current-block burn-block-height)
    )
    (map-set property-disputes property-id
      {
        plaintiff: tx-sender,
        defendant: defendant,
        dispute-reason: reason,
        filed-at: current-block,
        resolved: false,
        resolution: none
      })
    (ok true)))

(define-public (resolve-dispute 
  (property-id uint)
  (resolution (string-ascii 512)))
  (let 
    (
      (dispute (unwrap! (map-get? property-disputes property-id) ERR_PROPERTY_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender (var-get contract-admin)) ERR_UNAUTHORIZED)
    (map-set property-disputes property-id
      (merge dispute {
        resolved: true,
        resolution: (some resolution)
      }))
    (ok true)))

(define-public (update-property-value 
  (property-id uint)
  (new-value uint))
  (let 
    (
      (property (unwrap! (map-get? properties property-id) ERR_PROPERTY_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender (get owner property)) ERR_INVALID_OWNER)
    (map-set properties property-id
      (merge property {
        value: new-value,
        last-updated: burn-block-height
      }))
    (update-property-value-history property-id new-value)
    (ok true)))

(define-public (add-property-valuation
  (property-id uint)
  (valuation-amount uint)
  (valuation-type (string-ascii 32))
  (market-conditions (string-ascii 128))
  (confidence-score uint))
  (let 
    (
      (property (unwrap! (map-get? properties property-id) ERR_PROPERTY_NOT_FOUND))
      (valuation-count (default-to u0 (map-get? property-valuation-count property-id)))
      (current-block burn-block-height)
    )
    (asserts! (is-authorized-registrar tx-sender) ERR_UNAUTHORIZED)
    (asserts! (> valuation-amount u0) ERR_INVALID_VALUATION)
    (asserts! (<= confidence-score u100) ERR_INVALID_VALUATION)
    
    (map-set property-valuations
      {property-id: property-id, valuation-id: valuation-count}
      {
        appraiser: tx-sender,
        valuation-amount: valuation-amount,
        valuation-date: current-block,
        valuation-type: valuation-type,
        market-conditions: market-conditions,
        confidence-score: confidence-score
      })
    
    (map-set property-valuation-count property-id (+ valuation-count u1))
    (update-property-value-history property-id valuation-amount)
    (ok valuation-count)))

(define-public (get-property-market-trend (property-id uint))
  (let 
    (
      (value-history (unwrap! (map-get? property-value-history property-id) ERR_PROPERTY_NOT_FOUND))
      (current-value (get current-value value-history))
      (previous-value (get previous-value value-history))
      (change-percentage (get value-change-percentage value-history))
    )
    (ok {
      current-value: current-value,
      previous-value: previous-value,
      change-percentage: change-percentage,
      trend: (if (> change-percentage 0) "increasing" (if (< change-percentage 0) "decreasing" "stable"))
    })))

;; read-only functions

(define-read-only (get-property (property-id uint))
  (map-get? properties property-id))

(define-read-only (get-property-owner (property-id uint))
  (match (map-get? properties property-id)
    property (some (get owner property))
    none))

(define-read-only (get-transfer-history (property-id uint))
  (get-transfer-by-id property-id u0))

(define-read-only (get-properties-by-owner (owner principal))
  (default-to (list) (map-get? owner-properties owner)))

(define-read-only (is-property-verified (property-id uint))
  (match (map-get? properties property-id)
    property (get verified property)
    false))

(define-read-only (is-authorized-registrar (registrar principal))
  (default-to false (map-get? authorized-registrars registrar)))

(define-read-only (get-contract-admin)
  (var-get contract-admin))

(define-read-only (get-total-properties)
  (- (var-get next-property-id) u1))

(define-read-only (get-dispute (property-id uint))
  (map-get? property-disputes property-id))

(define-read-only (verify-ownership (property-id uint) (claimed-owner principal))
  (match (get-property-owner property-id)
    actual-owner (is-eq actual-owner claimed-owner)
    false))

(define-read-only (get-property-valuation-history (property-id uint))
  (let 
    (
      (valuation-count (default-to u0 (map-get? property-valuation-count property-id)))
    )
    (if (> valuation-count u0)
      (get-valuation-by-id property-id (- valuation-count u1))
      none)))

(define-read-only (get-property-value-history (property-id uint))
  (map-get? property-value-history property-id))

(define-read-only (get-property-valuation-count (property-id uint))
  (default-to u0 (map-get? property-valuation-count property-id)))

(define-read-only (calculate-property-appreciation (property-id uint))
  (let 
    (
      (value-history (unwrap! (map-get? property-value-history property-id) (err u0)))
      (current-value (get current-value value-history))
      (previous-value (get previous-value value-history))
    )
    (if (> previous-value u0)
      (ok (to-int (/ (* (- current-value previous-value) u100) previous-value)))
      (ok 0))))

;; private functions

(define-private (update-owner-properties (owner principal) (property-id uint) (add bool))
  (let 
    (
      (current-properties (default-to (list) (map-get? owner-properties owner)))
    )
    (if add
      (map-set owner-properties owner (unwrap-panic (as-max-len? (append current-properties property-id) u100)))
      (map-delete owner-properties owner))))

(define-private (get-transfer-by-id (property-id uint) (transfer-id uint))
  (map-get? property-transfers {property-id: property-id, transfer-id: transfer-id}))

(define-private (get-valuation-by-id (property-id uint) (valuation-id uint))
  (map-get? property-valuations {property-id: property-id, valuation-id: valuation-id}))

(define-private (update-property-value-history (property-id uint) (new-value uint))
  (let 
    (
      (current-history (default-to 
        {
          current-value: u0,
          previous-value: u0,
          value-change-percentage: 0,
          last-valuation-date: u0,
          total-valuations: u0
        }
        (map-get? property-value-history property-id)))
      (current-value (get current-value current-history))
      (total-valuations (get total-valuations current-history))
      (percentage-change (if (> current-value u0)
        (to-int (/ (* (- new-value current-value) u100) current-value))
        0))
    )
    (map-set property-value-history property-id
      {
        current-value: new-value,
        previous-value: current-value,
        value-change-percentage: percentage-change,
        last-valuation-date: burn-block-height,
        total-valuations: (+ total-valuations u1)
      })
    true))
