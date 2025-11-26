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
(define-constant ERR_LEASE_NOT_FOUND (err u409))
(define-constant ERR_LEASE_ACTIVE (err u410))
(define-constant ERR_LEASE_EXPIRED (err u411))
(define-constant ERR_INVALID_LEASE_TERMS (err u412))
(define-constant ERR_INSURANCE_NOT_FOUND (err u413))
(define-constant ERR_INSURANCE_EXPIRED (err u414))
(define-constant ERR_CLAIM_NOT_FOUND (err u415))
(define-constant ERR_CLAIM_ALREADY_PROCESSED (err u416))
(define-constant ERR_INVALID_PROVIDER (err u417))
(define-constant ERR_INSUFFICIENT_COVERAGE (err u418))
(define-constant ERR_INVALID_PREMIUM (err u419))
(define-constant ERR_POLICY_ACTIVE (err u420))
(define-constant ERR_NOT_CO_OWNER (err u421))
(define-constant ERR_INVALID_SHARE_PERCENTAGE (err u422))
(define-constant ERR_SHARES_EXCEED_100 (err u423))
(define-constant ERR_CO_OWNERSHIP_EXISTS (err u424))
(define-constant ERR_PROPOSAL_NOT_FOUND (err u425))
(define-constant ERR_ALREADY_VOTED (err u426))
(define-constant ERR_PROPOSAL_EXECUTED (err u427))
(define-constant ERR_INSUFFICIENT_VOTES (err u428))
(define-constant ERR_INVALID_SHARE_TRANSFER (err u429))
(define-constant ERR_LISTING_NOT_FOUND (err u430))
(define-constant ERR_PRICE_MUST_BE_POSITIVE (err u431))
(define-constant ERR_ALREADY_LISTED (err u432))
(define-constant ERR_PAYMENT_FAILED (err u433))

;; data vars
(define-data-var next-property-id uint u1)
(define-data-var contract-admin principal CONTRACT_OWNER)
(define-data-var next-lease-id uint u1)
(define-data-var next-policy-id uint u1)
(define-data-var next-claim-id uint u1)
(define-data-var next-proposal-id uint u1)

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

(define-map property-leases
  uint
  {
    property-id: uint,
    landlord: principal,
    tenant: principal,
    monthly-rent: uint,
    security-deposit: uint,
    lease-start: uint,
    lease-end: uint,
    lease-status: (string-ascii 16),
    created-at: uint
  })

(define-map active-property-leases uint uint)

(define-map tenant-lease-history principal (list 50 uint))

(define-map landlord-lease-history principal (list 100 uint))

(define-map authorized-insurance-providers principal bool)

(define-map property-insurance-policies
  uint
  {
    policy-id: uint,
    property-id: uint,
    policy-holder: principal,
    insurance-provider: principal,
    coverage-amount: uint,
    annual-premium: uint,
    policy-start: uint,
    policy-end: uint,
    coverage-type: (string-ascii 64),
    policy-status: (string-ascii 16),
    created-at: uint
  })

(define-map property-active-policies uint uint)

(define-map insurance-claims
  uint
  {
    policy-id: uint,
    claimant: principal,
    claim-amount: uint,
    incident-date: uint,
    claim-description: (string-ascii 512),
    claim-status: (string-ascii 16),
    filed-at: uint,
    processed-at: uint,
    payout-amount: uint,
    adjuster: (optional principal)
  })

(define-map policy-claim-history uint (list 20 uint))

(define-map property-co-ownership
  {property-id: uint, co-owner: principal}
  {
    share-percentage: uint,
    added-at: uint,
    is-active: bool
  })

(define-map property-co-owners
  uint
  {co-owners: (list 20 principal), total-shares: uint})

(define-map co-ownership-proposals
  uint
  {
    property-id: uint,
    proposer: principal,
    proposal-type: (string-ascii 32),
    description: (string-ascii 256),
    target-principal: (optional principal),
    target-value: uint,
    votes-for: uint,
    votes-against: uint,
    required-percentage: uint,
    created-at: uint,
    executed: bool,
    execution-deadline: uint
  })

(define-map proposal-votes
  {proposal-id: uint, voter: principal}
  {vote: bool, voting-power: uint})

(define-map property-proposal-history
  uint
  (list 50 uint))

(define-map property-listings
  uint
  {
    seller: principal,
    price: uint,
    listed-at: uint
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

(define-public (create-lease
  (property-id uint)
  (tenant principal)
  (monthly-rent uint)
  (security-deposit uint)
  (lease-duration uint))
  (let 
    (
      (property (unwrap! (map-get? properties property-id) ERR_PROPERTY_NOT_FOUND))
      (property-owner (get owner property))
      (lease-id (var-get next-lease-id))
      (current-block burn-block-height)
      (lease-end-block (+ current-block lease-duration))
      (existing-lease (map-get? active-property-leases property-id))
    )
    (asserts! (is-eq tx-sender property-owner) ERR_INVALID_OWNER)
    (asserts! (is-none existing-lease) ERR_LEASE_ACTIVE)
    (asserts! (> monthly-rent u0) ERR_INVALID_LEASE_TERMS)
    (asserts! (> lease-duration u0) ERR_INVALID_LEASE_TERMS)
    (asserts! (not (is-eq tx-sender tenant)) ERR_INVALID_LEASE_TERMS)

    (map-set property-leases lease-id
      {
        property-id: property-id,
        landlord: tx-sender,
        tenant: tenant,
        monthly-rent: monthly-rent,
        security-deposit: security-deposit,
        lease-start: current-block,
        lease-end: lease-end-block,
        lease-status: "active",
        created-at: current-block
      })

    (map-set active-property-leases property-id lease-id)
    (update-tenant-lease-history tenant lease-id)
    (update-landlord-lease-history tx-sender lease-id)
    (var-set next-lease-id (+ lease-id u1))
    (ok lease-id)))

(define-public (terminate-lease (lease-id uint))
  (let 
    (
      (lease (unwrap! (map-get? property-leases lease-id) ERR_LEASE_NOT_FOUND))
      (landlord (get landlord lease))
      (property-id (get property-id lease))
      (lease-status (get lease-status lease))
    )
    (asserts! (is-eq tx-sender landlord) ERR_INVALID_OWNER)
    (asserts! (is-eq lease-status "active") ERR_LEASE_EXPIRED)

    (map-set property-leases lease-id
      (merge lease {lease-status: "terminated"}))
    (map-delete active-property-leases property-id)
    (ok true)))

(define-public (renew-lease 
  (lease-id uint)
  (new-duration uint)
  (new-rent uint))
  (let 
    (
      (lease (unwrap! (map-get? property-leases lease-id) ERR_LEASE_NOT_FOUND))
      (landlord (get landlord lease))
      (current-block burn-block-height)
      (new-lease-end (+ current-block new-duration))
    )
    (asserts! (is-eq tx-sender landlord) ERR_INVALID_OWNER)
    (asserts! (is-eq (get lease-status lease) "active") ERR_LEASE_EXPIRED)
    (asserts! (> new-duration u0) ERR_INVALID_LEASE_TERMS)
    (asserts! (> new-rent u0) ERR_INVALID_LEASE_TERMS)

    (map-set property-leases lease-id
      (merge lease {
        lease-end: new-lease-end,
        monthly-rent: new-rent
      }))
    (ok true)))

(define-public (authorize-insurance-provider (provider principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-admin)) ERR_UNAUTHORIZED)
    (map-set authorized-insurance-providers provider true)
    (ok true)))

(define-public (revoke-insurance-provider (provider principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-admin)) ERR_UNAUTHORIZED)
    (map-delete authorized-insurance-providers provider)
    (ok true)))

(define-public (purchase-insurance-policy
  (property-id uint)
  (insurance-provider principal)
  (coverage-amount uint)
  (annual-premium uint)
  (policy-duration uint)
  (coverage-type (string-ascii 64)))
  (let 
    (
      (property (unwrap! (map-get? properties property-id) ERR_PROPERTY_NOT_FOUND))
      (property-owner (get owner property))
      (policy-id (var-get next-policy-id))
      (current-block burn-block-height)
      (policy-end-block (+ current-block policy-duration))
      (existing-policy (map-get? property-active-policies property-id))
    )
    (asserts! (is-eq tx-sender property-owner) ERR_INVALID_OWNER)
    (asserts! (is-authorized-insurance-provider insurance-provider) ERR_INVALID_PROVIDER)
    (asserts! (is-none existing-policy) ERR_POLICY_ACTIVE)
    (asserts! (> coverage-amount u0) ERR_INVALID_PREMIUM)
    (asserts! (> annual-premium u0) ERR_INVALID_PREMIUM)
    (asserts! (> policy-duration u0) ERR_INVALID_LEASE_TERMS)

    (map-set property-insurance-policies policy-id
      {
        policy-id: policy-id,
        property-id: property-id,
        policy-holder: property-owner,
        insurance-provider: insurance-provider,
        coverage-amount: coverage-amount,
        annual-premium: annual-premium,
        policy-start: current-block,
        policy-end: policy-end-block,
        coverage-type: coverage-type,
        policy-status: "active",
        created-at: current-block
      })

    (map-set property-active-policies property-id policy-id)
    (map-set policy-claim-history policy-id (list))
    (var-set next-policy-id (+ policy-id u1))
    (ok policy-id)))

(define-public (cancel-insurance-policy (policy-id uint))
  (let 
    (
      (policy (unwrap! (map-get? property-insurance-policies policy-id) ERR_INSURANCE_NOT_FOUND))
      (policy-holder (get policy-holder policy))
      (insurance-provider (get insurance-provider policy))
      (property-id (get property-id policy))
    )
    (asserts! (or (is-eq tx-sender policy-holder) (is-eq tx-sender insurance-provider)) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get policy-status policy) "active") ERR_INSURANCE_EXPIRED)

    (map-set property-insurance-policies policy-id
      (merge policy {policy-status: "cancelled"}))
    (map-delete property-active-policies property-id)
    (ok true)))

(define-public (renew-insurance-policy 
  (policy-id uint)
  (new-duration uint)
  (new-premium uint))
  (let 
    (
      (policy (unwrap! (map-get? property-insurance-policies policy-id) ERR_INSURANCE_NOT_FOUND))
      (insurance-provider (get insurance-provider policy))
      (current-block burn-block-height)
      (new-policy-end (+ current-block new-duration))
    )
    (asserts! (is-eq tx-sender insurance-provider) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get policy-status policy) "active") ERR_INSURANCE_EXPIRED)
    (asserts! (> new-duration u0) ERR_INVALID_LEASE_TERMS)
    (asserts! (> new-premium u0) ERR_INVALID_PREMIUM)

    (map-set property-insurance-policies policy-id
      (merge policy {
        policy-end: new-policy-end,
        annual-premium: new-premium
      }))
    (ok true)))

(define-public (file-insurance-claim
  (policy-id uint)
  (claim-amount uint)
  (incident-date uint)
  (claim-description (string-ascii 512)))
  (let 
    (
      (policy (unwrap! (map-get? property-insurance-policies policy-id) ERR_INSURANCE_NOT_FOUND))
      (policy-holder (get policy-holder policy))
      (coverage-amount (get coverage-amount policy))
      (claim-id (var-get next-claim-id))
      (current-block burn-block-height)
      (claim-history (default-to (list) (map-get? policy-claim-history policy-id)))
    )
    (asserts! (is-eq tx-sender policy-holder) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get policy-status policy) "active") ERR_INSURANCE_EXPIRED)
    (asserts! (< current-block (get policy-end policy)) ERR_INSURANCE_EXPIRED)
    (asserts! (<= claim-amount coverage-amount) ERR_INSUFFICIENT_COVERAGE)
    (asserts! (> claim-amount u0) ERR_INVALID_PREMIUM)
    (asserts! (<= incident-date current-block) ERR_INVALID_LEASE_TERMS)

    (map-set insurance-claims claim-id
      {
        policy-id: policy-id,
        claimant: tx-sender,
        claim-amount: claim-amount,
        incident-date: incident-date,
        claim-description: claim-description,
        claim-status: "pending",
        filed-at: current-block,
        processed-at: u0,
        payout-amount: u0,
        adjuster: none
      })

    (map-set policy-claim-history policy-id
      (unwrap-panic (as-max-len? (append claim-history claim-id) u20)))
    (var-set next-claim-id (+ claim-id u1))
    (ok claim-id)))

(define-public (process-insurance-claim 
  (claim-id uint)
  (approved bool)
  (payout-amount uint))
  (let 
    (
      (claim (unwrap! (map-get? insurance-claims claim-id) ERR_CLAIM_NOT_FOUND))
      (policy-id (get policy-id claim))
      (policy (unwrap! (map-get? property-insurance-policies policy-id) ERR_INSURANCE_NOT_FOUND))
      (insurance-provider (get insurance-provider policy))
      (current-block burn-block-height)
    )
    (asserts! (is-eq tx-sender insurance-provider) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get claim-status claim) "pending") ERR_CLAIM_ALREADY_PROCESSED)
    (asserts! (<= payout-amount (get claim-amount claim)) ERR_INSUFFICIENT_COVERAGE)

    (map-set insurance-claims claim-id
      (merge claim {
        claim-status: (if approved "approved" "denied"),
        processed-at: current-block,
        payout-amount: (if approved payout-amount u0),
        adjuster: (some tx-sender)
      }))
    (ok true)))

(define-public (investigate-claim (claim-id uint) (adjuster principal))
  (let 
    (
      (claim (unwrap! (map-get? insurance-claims claim-id) ERR_CLAIM_NOT_FOUND))
      (policy-id (get policy-id claim))
      (policy (unwrap! (map-get? property-insurance-policies policy-id) ERR_INSURANCE_NOT_FOUND))
      (insurance-provider (get insurance-provider policy))
    )
    (asserts! (is-eq tx-sender insurance-provider) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get claim-status claim) "pending") ERR_CLAIM_ALREADY_PROCESSED)

    (map-set insurance-claims claim-id
      (merge claim {
        claim-status: "investigating",
        adjuster: (some adjuster)
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

(define-read-only (get-lease (lease-id uint))
  (map-get? property-leases lease-id))

(define-read-only (get-active-lease-by-property (property-id uint))
  (match (map-get? active-property-leases property-id)
    lease-id (map-get? property-leases lease-id)
    none))

(define-read-only (get-tenant-lease-history (tenant principal))
  (default-to (list) (map-get? tenant-lease-history tenant)))

(define-read-only (get-landlord-lease-history (landlord principal))
  (default-to (list) (map-get? landlord-lease-history landlord)))

(define-read-only (is-lease-active (lease-id uint))
  (match (map-get? property-leases lease-id)
    lease 
      (and 
        (is-eq (get lease-status lease) "active")
        (< burn-block-height (get lease-end lease)))
    false))

(define-read-only (get-lease-status (property-id uint))
  (match (get-active-lease-by-property property-id)
    lease
      (some {
        lease-id: (unwrap-panic (map-get? active-property-leases property-id)),
        tenant: (get tenant lease),
        monthly-rent: (get monthly-rent lease),
        lease-end: (get lease-end lease),
      status: (get lease-status lease)
      })
    none))

(define-read-only (get-insurance-policy (policy-id uint))
  (map-get? property-insurance-policies policy-id))

(define-read-only (get-property-insurance (property-id uint))
  (match (map-get? property-active-policies property-id)
    policy-id (map-get? property-insurance-policies policy-id)
    none))

(define-read-only (get-insurance-claim (claim-id uint))
  (map-get? insurance-claims claim-id))

(define-read-only (get-policy-claims (policy-id uint))
  (default-to (list) (map-get? policy-claim-history policy-id)))

(define-read-only (is-authorized-insurance-provider (provider principal))
  (default-to false (map-get? authorized-insurance-providers provider)))

(define-read-only (is-policy-active (policy-id uint))
  (match (map-get? property-insurance-policies policy-id)
    policy 
      (and 
        (is-eq (get policy-status policy) "active")
        (< burn-block-height (get policy-end policy)))
    false))

(define-read-only (calculate-insurance-premium-due (policy-id uint))
  (match (map-get? property-insurance-policies policy-id)
    policy
      (let 
        (
          (annual-premium (get annual-premium policy))
          (policy-start (get policy-start policy))
          (current-block burn-block-height)
          (blocks-elapsed (- current-block policy-start))
          (yearly-blocks u52560)
        )
        (ok (/ (* annual-premium blocks-elapsed) yearly-blocks)))
    ERR_INSURANCE_NOT_FOUND))

(define-read-only (get-property-insurance-status (property-id uint))
  (match (get-property-insurance property-id)
    insurance-policy
      (some {
        policy-id: (get policy-id insurance-policy),
        coverage-amount: (get coverage-amount insurance-policy),
        annual-premium: (get annual-premium insurance-policy),
        policy-end: (get policy-end insurance-policy),
        coverage-type: (get coverage-type insurance-policy),
        is-active: (is-policy-active (get policy-id insurance-policy))
      })
    none))

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

(define-private (update-tenant-lease-history (tenant principal) (lease-id uint))
  (let 
    (
      (current-history (default-to (list) (map-get? tenant-lease-history tenant)))
    )
    (map-set tenant-lease-history tenant 
      (unwrap-panic (as-max-len? (append current-history lease-id) u50)))))

(define-private (update-landlord-lease-history (landlord principal) (lease-id uint))
  (let 
    (
      (current-history (default-to (list) (map-get? landlord-lease-history landlord)))
    )
    (map-set landlord-lease-history landlord 
      (unwrap-panic (as-max-len? (append current-history lease-id) u100)))))

(define-public (create-co-ownership
  (property-id uint)
  (co-owners-list (list 20 {owner: principal, share: uint})))
  (let 
    (
      (property (unwrap! (map-get? properties property-id) ERR_PROPERTY_NOT_FOUND))
      (property-owner (get owner property))
      (total-shares (fold sum-shares co-owners-list u0))
      (co-owner-principals (map extract-principal co-owners-list))
    )
    (asserts! (is-eq tx-sender property-owner) ERR_INVALID_OWNER)
    (asserts! (is-none (map-get? property-co-owners property-id)) ERR_CO_OWNERSHIP_EXISTS)
    (asserts! (is-eq total-shares u10000) ERR_SHARES_EXCEED_100)
    (asserts! (> (len co-owners-list) u0) ERR_INVALID_SHARE_PERCENTAGE)
    
    (fold setup-co-owner co-owners-list {property-id: property-id, success: true})
    
    (map-set property-co-owners property-id
      {co-owners: co-owner-principals, total-shares: total-shares})
    
    (map-set property-proposal-history property-id (list))
    (ok true)))

(define-public (transfer-ownership-share
  (property-id uint)
  (new-owner principal)
  (share-percentage uint))
  (let 
    (
      (co-ownership (unwrap! (map-get? property-co-ownership {property-id: property-id, co-owner: tx-sender}) ERR_NOT_CO_OWNER))
      (current-share (get share-percentage co-ownership))
      (current-block burn-block-height)
    )
    (asserts! (get is-active co-ownership) ERR_NOT_CO_OWNER)
    (asserts! (<= share-percentage current-share) ERR_INVALID_SHARE_TRANSFER)
    (asserts! (> share-percentage u0) ERR_INVALID_SHARE_PERCENTAGE)
    (asserts! (not (is-eq tx-sender new-owner)) ERR_INVALID_TRANSFER)
    
    (if (is-eq share-percentage current-share)
      (begin
        (map-set property-co-ownership {property-id: property-id, co-owner: tx-sender}
          (merge co-ownership {is-active: false}))
        (map-set property-co-ownership {property-id: property-id, co-owner: new-owner}
          {
            share-percentage: share-percentage,
            added-at: current-block,
            is-active: true
          })
        (update-co-owners-list property-id tx-sender new-owner))
      (begin
        (map-set property-co-ownership {property-id: property-id, co-owner: tx-sender}
          (merge co-ownership {share-percentage: (- current-share share-percentage)}))
        (map-set property-co-ownership {property-id: property-id, co-owner: new-owner}
          {
            share-percentage: share-percentage,
            added-at: current-block,
            is-active: true
          })
        (add-co-owner-to-list property-id new-owner)))
    (ok true)))

(define-public (create-co-ownership-proposal
  (property-id uint)
  (proposal-type (string-ascii 32))
  (description (string-ascii 256))
  (target-principal (optional principal))
  (target-value uint)
  (execution-deadline uint))
  (let 
    (
      (co-ownership (unwrap! (map-get? property-co-ownership {property-id: property-id, co-owner: tx-sender}) ERR_NOT_CO_OWNER))
      (proposal-id (var-get next-proposal-id))
      (current-block burn-block-height)
    )
    (asserts! (get is-active co-ownership) ERR_NOT_CO_OWNER)
    (asserts! (> execution-deadline current-block) ERR_INVALID_LEASE_TERMS)
    
    (map-set co-ownership-proposals proposal-id
      {
        property-id: property-id,
        proposer: tx-sender,
        proposal-type: proposal-type,
        description: description,
        target-principal: target-principal,
        target-value: target-value,
        votes-for: u0,
        votes-against: u0,
        required-percentage: u6700,
        created-at: current-block,
        executed: false,
        execution-deadline: execution-deadline
      })
    
    (let 
      (
        (proposal-history (default-to (list) (map-get? property-proposal-history property-id)))
      )
      (map-set property-proposal-history property-id
        (unwrap-panic (as-max-len? (append proposal-history proposal-id) u50))))
    
    (var-set next-proposal-id (+ proposal-id u1))
    (ok proposal-id)))

(define-public (vote-on-proposal
  (proposal-id uint)
  (vote-for bool))
  (let 
    (
      (proposal (unwrap! (map-get? co-ownership-proposals proposal-id) ERR_PROPOSAL_NOT_FOUND))
      (property-id (get property-id proposal))
      (co-ownership (unwrap! (map-get? property-co-ownership {property-id: property-id, co-owner: tx-sender}) ERR_NOT_CO_OWNER))
      (voting-power (get share-percentage co-ownership))
      (current-block burn-block-height)
    )
    (asserts! (get is-active co-ownership) ERR_NOT_CO_OWNER)
    (asserts! (not (get executed proposal)) ERR_PROPOSAL_EXECUTED)
    (asserts! (< current-block (get execution-deadline proposal)) ERR_LEASE_EXPIRED)
    (asserts! (is-none (map-get? proposal-votes {proposal-id: proposal-id, voter: tx-sender})) ERR_ALREADY_VOTED)
    
    (map-set proposal-votes {proposal-id: proposal-id, voter: tx-sender}
      {vote: vote-for, voting-power: voting-power})
    
    (if vote-for
      (map-set co-ownership-proposals proposal-id
        (merge proposal {votes-for: (+ (get votes-for proposal) voting-power)}))
      (map-set co-ownership-proposals proposal-id
        (merge proposal {votes-against: (+ (get votes-against proposal) voting-power)})))
    (ok true)))

(define-public (execute-co-ownership-proposal (proposal-id uint))
  (let 
    (
      (proposal (unwrap! (map-get? co-ownership-proposals proposal-id) ERR_PROPOSAL_NOT_FOUND))
      (property-id (get property-id proposal))
      (co-ownership (unwrap! (map-get? property-co-ownership {property-id: property-id, co-owner: tx-sender}) ERR_NOT_CO_OWNER))
      (votes-for (get votes-for proposal))
      (total-votes (+ votes-for (get votes-against proposal)))
      (required-percentage (get required-percentage proposal))
      (current-block burn-block-height)
    )
    (asserts! (get is-active co-ownership) ERR_NOT_CO_OWNER)
    (asserts! (not (get executed proposal)) ERR_PROPOSAL_EXECUTED)
    (asserts! (>= current-block (get execution-deadline proposal)) ERR_PROPOSAL_EXECUTED)
    (asserts! (>= (* votes-for u100) (* total-votes (/ required-percentage u100))) ERR_INSUFFICIENT_VOTES)
    
    (map-set co-ownership-proposals proposal-id
      (merge proposal {executed: true}))
    (ok true)))

(define-public (list-property (property-id uint) (price uint))
  (let
    (
      (property (unwrap! (map-get? properties property-id) ERR_PROPERTY_NOT_FOUND))
      (owner (get owner property))
    )
    (asserts! (is-eq tx-sender owner) ERR_INVALID_OWNER)
    (asserts! (> price u0) ERR_PRICE_MUST_BE_POSITIVE)
    (asserts! (is-none (map-get? property-listings property-id)) ERR_ALREADY_LISTED)

    (map-set property-listings property-id
      {
        seller: tx-sender,
        price: price,
        listed-at: burn-block-height
      })
    (ok true)))

(define-public (unlist-property (property-id uint))
  (let
    (
      (listing (unwrap! (map-get? property-listings property-id) ERR_LISTING_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender (get seller listing)) ERR_UNAUTHORIZED)
    (map-delete property-listings property-id)
    (ok true)))

(define-public (purchase-property (property-id uint))
  (let
    (
      (listing (unwrap! (map-get? property-listings property-id) ERR_LISTING_NOT_FOUND))
      (property (unwrap! (map-get? properties property-id) ERR_PROPERTY_NOT_FOUND))
      (seller (get seller listing))
      (price (get price listing))
      (buyer tx-sender)
      (current-owner (get owner property))
      (transfer-count (default-to u0 (map-get? property-transfer-count property-id)))
      (current-block burn-block-height)
    )
    ;; Verify seller is still owner
    (asserts! (is-eq seller current-owner) ERR_INVALID_OWNER)
    (asserts! (not (is-eq buyer seller)) ERR_INVALID_TRANSFER)

    ;; Transfer STX
    (unwrap! (stx-transfer? price buyer seller) ERR_PAYMENT_FAILED)

    ;; Transfer Property Ownership
    (map-set properties property-id
      (merge property {
        owner: buyer,
        last-updated: current-block,
        value: price
      }))

    (map-set property-transfers
      {property-id: property-id, transfer-id: transfer-count}
      {
        from: seller,
        to: buyer,
        transfer-date: current-block,
        transfer-value: price,
        transfer-type: "market-sale"
      })

    (map-set property-transfer-count property-id (+ transfer-count u1))
    (update-property-value-history property-id price)
    (update-owner-properties seller property-id false)
    (update-owner-properties buyer property-id true)

    ;; Remove listing
    (map-delete property-listings property-id)
    (ok true)))

(define-read-only (get-co-ownership-info (property-id uint))
  (map-get? property-co-owners property-id))

(define-read-only (get-co-owner-share (property-id uint) (co-owner principal))
  (map-get? property-co-ownership {property-id: property-id, co-owner: co-owner}))

(define-read-only (get-co-ownership-proposal (proposal-id uint))
  (map-get? co-ownership-proposals proposal-id))

(define-read-only (get-proposal-vote (proposal-id uint) (voter principal))
  (map-get? proposal-votes {proposal-id: proposal-id, voter: voter}))

(define-read-only (get-property-proposals (property-id uint))
  (default-to (list) (map-get? property-proposal-history property-id)))

(define-read-only (is-co-owner (property-id uint) (potential-owner principal))
  (match (map-get? property-co-ownership {property-id: property-id, co-owner: potential-owner})
    ownership (get is-active ownership)
    false))

(define-read-only (calculate-proposal-status (proposal-id uint))
  (match (map-get? co-ownership-proposals proposal-id)
    proposal
      (let 
        (
          (votes-for (get votes-for proposal))
          (votes-against (get votes-against proposal))
          (total-votes (+ votes-for votes-against))
          (required-percentage (get required-percentage proposal))
          (current-block burn-block-height)
          (is-expired (>= current-block (get execution-deadline proposal)))
        )
        (ok {
          votes-for: votes-for,
          votes-against: votes-against,
          total-votes: total-votes,
          approval-rate: (if (> total-votes u0) (/ (* votes-for u10000) total-votes) u0),
          is-passing: (>= (* votes-for u100) (* total-votes (/ required-percentage u100))),
          is-executed: (get executed proposal),
          is-expired: is-expired
        }))
    ERR_PROPOSAL_NOT_FOUND))

(define-read-only (get-listing (property-id uint))
  (map-get? property-listings property-id))

(define-private (sum-shares (co-owner-data {owner: principal, share: uint}) (total uint))
  (+ total (get share co-owner-data)))

(define-private (extract-principal (co-owner-data {owner: principal, share: uint}))
  (get owner co-owner-data))

(define-private (setup-co-owner (co-owner-data {owner: principal, share: uint}) (context {property-id: uint, success: bool}))
  (let 
    (
      (property-id (get property-id context))
      (owner (get owner co-owner-data))
      (share (get share co-owner-data))
      (current-block burn-block-height)
    )
    (begin
      (map-set property-co-ownership {property-id: property-id, co-owner: owner}
        {
          share-percentage: share,
          added-at: current-block,
          is-active: true
        })
      context)))

(define-private (update-co-owners-list (property-id uint) (old-owner principal) (new-owner principal))
  (let 
    (
      (co-owners-data (unwrap-panic (map-get? property-co-owners property-id)))
      (current-owners (get co-owners co-owners-data))
      (filtered-result (fold filter-old-owner current-owners {target: old-owner, result: (list)}))
      (filtered-owners (get result filtered-result))
    )
    (map-set property-co-owners property-id
      (merge co-owners-data {co-owners: (unwrap-panic (as-max-len? (append filtered-owners new-owner) u20))}))))

(define-private (filter-old-owner (owner principal) (acc {target: principal, result: (list 20 principal)}))
  (if (is-eq owner (get target acc))
    acc
    (merge acc {result: (unwrap-panic (as-max-len? (append (get result acc) owner) u20))})))

(define-private (add-co-owner-to-list (property-id uint) (new-owner principal))
  (let 
    (
      (co-owners-data (unwrap-panic (map-get? property-co-owners property-id)))
      (current-owners (get co-owners co-owners-data))
    )
    (if (is-none (index-of current-owners new-owner))
      (map-set property-co-owners property-id
        (merge co-owners-data {co-owners: (unwrap-panic (as-max-len? (append current-owners new-owner) u20))}))
      true)))
