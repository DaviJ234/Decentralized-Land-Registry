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
    (ok true)))

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
