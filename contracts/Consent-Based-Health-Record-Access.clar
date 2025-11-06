(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_NOT_FOUND (err u101))
(define-constant ERR_ALREADY_EXISTS (err u102))
(define-constant ERR_EXPIRED (err u103))
(define-constant ERR_INVALID_DURATION (err u104))
(define-constant ERR_SELF_ACCESS (err u105))
(define-constant ERR_EMERGENCY_NOT_FOUND (err u106))
(define-constant ERR_EMERGENCY_EXPIRED (err u107))
(define-constant EMERGENCY_ACCESS_DURATION u144)

(define-constant ERR_RATING_INVALID (err u109))
(define-constant ERR_ANALYTICS_NOT_FOUND (err u110))

(define-constant ERR_DELEGATE_EXISTS (err u111))
(define-constant ERR_NOT_DELEGATE (err u112))
(define-constant ERR_DELEGATE_EXPIRED (err u113))

(define-constant ERR_TEMPLATE_NOT_FOUND (err u114))
(define-constant ERR_TEMPLATE_EXISTS (err u115))
(define-constant ERR_TEMPLATE_INACTIVE (err u116))

(define-map patients principal 
  {
    name: (string-ascii 50),
    registered-at: uint,
    active: bool
  }
)

(define-map health-records principal 
  {
    record-hash: (buff 32),
    created-at: uint,
    updated-at: uint,
    record-type: (string-ascii 20)
  }
)

(define-map consent-requests 
  { patient: principal, requester: principal }
  {
    purpose: (string-ascii 100),
    requested-at: uint,
    status: (string-ascii 10),
    expires-at: uint,
    record-types: (list 5 (string-ascii 20))
  }
)

(define-map active-consents
  { patient: principal, accessor: principal }
  {
    granted-at: uint,
    expires-at: uint,
    purpose: (string-ascii 100),
    access-count: uint,
    record-types: (list 5 (string-ascii 20))
  }
)

(define-map healthcare-providers principal
  {
    name: (string-ascii 50),
    license-id: (string-ascii 30),
    verified: bool,
    registered-at: uint
  }
)

(define-data-var total-patients uint u0)
(define-data-var total-providers uint u0)
(define-data-var total-consents uint u0)

(define-public (register-patient (name (string-ascii 50)))
  (let ((patient tx-sender))
    (asserts! (is-none (map-get? patients patient)) ERR_ALREADY_EXISTS)
    (map-set patients patient {
      name: name,
      registered-at: stacks-block-height,
      active: true
    })
    (var-set total-patients (+ (var-get total-patients) u1))
    (ok true)
  )
)

(define-public (register-healthcare-provider (name (string-ascii 50)) (license-id (string-ascii 30)))
  (let ((provider tx-sender))
    (asserts! (is-none (map-get? healthcare-providers provider)) ERR_ALREADY_EXISTS)
    (map-set healthcare-providers provider {
      name: name,
      license-id: license-id,
      verified: false,
      registered-at: stacks-block-height
    })
    (var-set total-providers (+ (var-get total-providers) u1))
    (ok true)
  )
)

(define-public (verify-healthcare-provider (provider principal))
  (let ((provider-data (unwrap! (map-get? healthcare-providers provider) ERR_NOT_FOUND)))
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (map-set healthcare-providers provider 
      (merge provider-data { verified: true })
    )
    (ok true)
  )
)

(define-public (add-health-record (record-hash (buff 32)) (record-type (string-ascii 20)))
  (let ((patient tx-sender))
    (asserts! (is-some (map-get? patients patient)) ERR_NOT_FOUND)
    (map-set health-records patient {
      record-hash: record-hash,
      created-at: stacks-block-height,
      updated-at: stacks-block-height,
      record-type: record-type
    })
    (ok true)
  )
)

(define-public (request-consent 
  (patient principal) 
  (purpose (string-ascii 100)) 
  (duration uint)
  (record-types (list 5 (string-ascii 20)))
)
  (let (
    (requester tx-sender)
    (expires-at (+ stacks-block-height duration))
  )
    (asserts! (not (is-eq patient requester)) ERR_SELF_ACCESS)
    (asserts! (> duration u0) ERR_INVALID_DURATION)
    (asserts! (is-some (map-get? patients patient)) ERR_NOT_FOUND)
    (asserts! (is-some (map-get? healthcare-providers requester)) ERR_NOT_FOUND)
    (asserts! (get verified (unwrap! (map-get? healthcare-providers requester) ERR_NOT_FOUND)) ERR_UNAUTHORIZED)
    
    (map-set consent-requests { patient: patient, requester: requester } {
      purpose: purpose,
      requested-at: stacks-block-height,
      status: "pending",
      expires-at: expires-at,
      record-types: record-types
    })
    (ok true)
  )
)

(define-public (grant-consent (requester principal))
  (let (
    (patient tx-sender)
    (request-key { patient: patient, requester: requester })
    (request-data (unwrap! (map-get? consent-requests request-key) ERR_NOT_FOUND))
  )
    (asserts! (is-eq (get status request-data) "pending") ERR_UNAUTHORIZED)
    (asserts! (< stacks-block-height (get expires-at request-data)) ERR_EXPIRED)
    
    (map-set consent-requests request-key 
      (merge request-data { status: "approved" })
    )
    
    (map-set active-consents { patient: patient, accessor: requester } {
      granted-at: stacks-block-height,
      expires-at: (get expires-at request-data),
      purpose: (get purpose request-data),
      access-count: u0,
      record-types: (get record-types request-data)
    })
    
    (var-set total-consents (+ (var-get total-consents) u1))
    (ok true)
  )
)

(define-public (deny-consent (requester principal))
  (let (
    (patient tx-sender)
    (request-key { patient: patient, requester: requester })
    (request-data (unwrap! (map-get? consent-requests request-key) ERR_NOT_FOUND))
  )
    (asserts! (is-eq (get status request-data) "pending") ERR_UNAUTHORIZED)
    
    (map-set consent-requests request-key 
      (merge request-data { status: "denied" })
    )
    (ok true)
  )
)

(define-public (revoke-consent (accessor principal))
  (let (
    (patient tx-sender)
    (consent-key { patient: patient, accessor: accessor })
  )
    (asserts! (is-some (map-get? active-consents consent-key)) ERR_NOT_FOUND)
    (map-delete active-consents consent-key)
    (ok true)
  )
)

(define-public (access-health-record (patient principal))
  (let (
    (accessor tx-sender)
    (consent-key { patient: patient, accessor: accessor })
    (consent-data (unwrap! (map-get? active-consents consent-key) ERR_UNAUTHORIZED))
    (record-data (unwrap! (map-get? health-records patient) ERR_NOT_FOUND))
  )
    (asserts! (< stacks-block-height (get expires-at consent-data)) ERR_EXPIRED)
    
    (map-set active-consents consent-key
      (merge consent-data { 
        access-count: (+ (get access-count consent-data) u1)
      })
    )
    
    (ok {
      record-hash: (get record-hash record-data),
      record-type: (get record-type record-data),
      accessed-at: stacks-block-height
    })
  )
)

(define-read-only (get-patient-info (patient principal))
  (map-get? patients patient)
)

(define-read-only (get-provider-info (provider principal))
  (map-get? healthcare-providers provider)
)

(define-read-only (get-consent-request (patient principal) (requester principal))
  (map-get? consent-requests { patient: patient, requester: requester })
)

(define-read-only (get-active-consent (patient principal) (accessor principal))
  (map-get? active-consents { patient: patient, accessor: accessor })
)

(define-read-only (get-health-record-info (patient principal))
  (map-get? health-records patient)
)

(define-read-only (check-consent-validity (patient principal) (accessor principal))
  (match (map-get? active-consents { patient: patient, accessor: accessor })
    consent-data (< stacks-block-height (get expires-at consent-data))
    false
  )
)

(define-read-only (get-contract-stats)
  {
    total-patients: (var-get total-patients),
    total-providers: (var-get total-providers),
    total-consents: (var-get total-consents),
    contract-owner: CONTRACT_OWNER
  }
)


(define-map emergency-access-requests
  { patient: principal, emergency-contact: principal }
  {
    requested-at: uint,
    emergency-type: (string-ascii 30),
    location: (string-ascii 50),
    expires-at: uint,
    status: (string-ascii 10)
  }
)

(define-map emergency-consents
  { patient: principal, emergency-contact: principal }
  {
    granted-at: uint,
    expires-at: uint,
    emergency-type: (string-ascii 30),
    access-count: uint,
    auto-granted: bool
  }
)

(define-data-var total-emergency-requests uint u0)

(define-public (request-emergency-access 
  (patient principal) 
  (emergency-type (string-ascii 30)) 
  (location (string-ascii 50))
)
  (let (
    (emergency-contact tx-sender)
    (expires-at (+ stacks-block-height EMERGENCY_ACCESS_DURATION))
    (request-key { patient: patient, emergency-contact: emergency-contact })
  )
    (asserts! (not (is-eq patient emergency-contact)) ERR_SELF_ACCESS)
    (asserts! (is-some (map-get? patients patient)) ERR_NOT_FOUND)
    (asserts! (is-some (map-get? healthcare-providers emergency-contact)) ERR_NOT_FOUND)
    (asserts! (get verified (unwrap! (map-get? healthcare-providers emergency-contact) ERR_NOT_FOUND)) ERR_UNAUTHORIZED)
    
    (map-set emergency-access-requests request-key {
      requested-at: stacks-block-height,
      emergency-type: emergency-type,
      location: location,
      expires-at: expires-at,
      status: "pending"
    })
    
    (var-set total-emergency-requests (+ (var-get total-emergency-requests) u1))
    (ok true)
  )
)

(define-public (grant-emergency-access (emergency-contact principal))
  (let (
    (patient tx-sender)
    (request-key { patient: patient, emergency-contact: emergency-contact })
    (request-data (unwrap! (map-get? emergency-access-requests request-key) ERR_EMERGENCY_NOT_FOUND))
  )
    (asserts! (is-eq (get status request-data) "pending") ERR_UNAUTHORIZED)
    (asserts! (< stacks-block-height (get expires-at request-data)) ERR_EMERGENCY_EXPIRED)
    
    (map-set emergency-access-requests request-key 
      (merge request-data { status: "approved" })
    )
    
    (map-set emergency-consents request-key {
      granted-at: stacks-block-height,
      expires-at: (get expires-at request-data),
      emergency-type: (get emergency-type request-data),
      access-count: u0,
      auto-granted: false
    })
    
    (ok true)
  )
)

(define-public (access-emergency-record (patient principal))
  (let (
    (emergency-contact tx-sender)
    (consent-key { patient: patient, emergency-contact: emergency-contact })
    (consent-data (unwrap! (map-get? emergency-consents consent-key) ERR_EMERGENCY_NOT_FOUND))
    (record-data (unwrap! (map-get? health-records patient) ERR_NOT_FOUND))
  )
    (asserts! (< stacks-block-height (get expires-at consent-data)) ERR_EMERGENCY_EXPIRED)
    
    (map-set emergency-consents consent-key
      (merge consent-data { 
        access-count: (+ (get access-count consent-data) u1)
      })
    )
    
    (ok {
      record-hash: (get record-hash record-data),
      record-type: (get record-type record-data),
      emergency-type: (get emergency-type consent-data),
      accessed-at: stacks-block-height
    })
  )
)

(define-read-only (get-emergency-request (patient principal) (emergency-contact principal))
  (map-get? emergency-access-requests { patient: patient, emergency-contact: emergency-contact })
)

(define-read-only (get-emergency-consent (patient principal) (emergency-contact principal))
  (map-get? emergency-consents { patient: patient, emergency-contact: emergency-contact })
)

(define-constant ERR_AUDIT_NOT_FOUND (err u108))

(define-map audit-trail
  { event-id: uint }
  {
    event-type: (string-ascii 30),
    actor: principal,
    target: principal,
    timestamp: uint,
    metadata: (string-ascii 100),
    block-height: uint
  }
)

(define-map patient-event-counts
  { patient: principal }
  { count: uint }
)

(define-data-var next-event-id uint u1)
(define-data-var total-audit-events uint u0)

(define-private (log-audit-event 
  (event-type (string-ascii 30))
  (actor principal)
  (target principal)
  (metadata (string-ascii 100))
)
  (let (
    (event-id (var-get next-event-id))
    (current-count (default-to u0 (get count (map-get? patient-event-counts { patient: target }))))
  )
    (map-set audit-trail { event-id: event-id } {
      event-type: event-type,
      actor: actor,
      target: target,
      timestamp: stacks-block-height,
      metadata: metadata,
      block-height: stacks-block-height
    })
    
    (map-set patient-event-counts { patient: target } { count: (+ current-count u1) })
    
    (var-set next-event-id (+ event-id u1))
    (var-set total-audit-events (+ (var-get total-audit-events) u1))
    (ok event-id)
  )
)

(define-public (get-audit-event (event-id uint))
  (ok (map-get? audit-trail { event-id: event-id }))
)

(define-read-only (get-patient-events (patient principal) (event-id uint))
  (match (map-get? audit-trail { event-id: event-id })
    event-data (if (is-eq (get target event-data) patient) (some event-data) none)
    none
  )
)

(define-read-only (get-patient-event-count (patient principal))
  (default-to u0 (get count (map-get? patient-event-counts { patient: patient })))
)

(define-read-only (get-audit-stats)
  {
    total-events: (var-get total-audit-events),
    next-event-id: (var-get next-event-id)
  }
)


(define-map patient-analytics
  { patient: principal }
  {
    total-accesses: uint,
    unique-accessors: uint,
    last-access: uint,
    avg-monthly-accesses: uint,
    most-accessed-record-type: (string-ascii 20),
    consent-grant-rate: uint
  }
)

(define-map provider-analytics
  { provider: principal }
  {
    total-requests: uint,
    approved-requests: uint,
    denied-requests: uint,
    avg-rating: uint,
    total-ratings: uint,
    last-activity: uint,
    reputation-score: uint
  }
)

(define-map access-metrics
  { patient: principal, provider: principal, date: uint }
  {
    access-count: uint,
    record-types-accessed: (list 5 (string-ascii 20)),
    session-duration: uint
  }
)

(define-map provider-ratings
  { patient: principal, provider: principal }
  {
    rating: uint,
    feedback: (string-ascii 200),
    rated-at: uint
  }
)

(define-data-var total-analytics-entries uint u0)

(define-public (rate-provider (provider principal) (rating uint) (feedback (string-ascii 200)))
  (let (
    (patient tx-sender)
    (rating-key { patient: patient, provider: provider })
  )
    (asserts! (and (>= rating u1) (<= rating u5)) ERR_RATING_INVALID)
    (asserts! (is-some (map-get? active-consents { patient: patient, accessor: provider })) ERR_UNAUTHORIZED)
    
    (map-set provider-ratings rating-key {
      rating: rating,
      feedback: feedback,
      rated-at: stacks-block-height
    })
    
    (if (update-provider-reputation provider rating) (ok true) (ok true))
  )
)

(define-private (update-provider-reputation (provider principal) (new-rating uint))
  (let (
    (current-analytics (default-to {
      total-requests: u0, approved-requests: u0, denied-requests: u0,
      avg-rating: u0, total-ratings: u0, last-activity: u0, reputation-score: u0
    } (map-get? provider-analytics { provider: provider })))
    (total-ratings (+ (get total-ratings current-analytics) u1))
    (rating-sum (+ (* (get avg-rating current-analytics) (get total-ratings current-analytics)) new-rating))
    (new-avg (/ rating-sum total-ratings))
    (reputation-score (+ (* new-avg u20) (if (< (* (get approved-requests current-analytics) u2) u100) (* (get approved-requests current-analytics) u2) u100)))
  )
    (begin
      (map-set provider-analytics { provider: provider }
        (merge current-analytics {
          avg-rating: new-avg,
          total-ratings: total-ratings,
          reputation-score: reputation-score,
          last-activity: stacks-block-height
        })
      )
      true
    )
  )
)

(define-read-only (get-patient-analytics (patient principal))
  (map-get? patient-analytics { patient: patient })
)

(define-read-only (get-provider-analytics (provider principal))
  (map-get? provider-analytics { provider: provider })
)

(define-read-only (get-provider-rating (patient principal) (provider principal))
  (map-get? provider-ratings { patient: patient, provider: provider })
)

(define-read-only (get-access-insights (patient principal))
  (let (
    (analytics (map-get? patient-analytics { patient: patient }))
  )
    (match analytics
      data (some {
        privacy-score: (- u100 (if (< (* (get total-accesses data) u2) u100) (* (get total-accesses data) u2) u100)),
        trust-level: (if (> (get consent-grant-rate data) u70) "high" 
                      (if (> (get consent-grant-rate data) u40) "medium" "low")),
        data-popularity: (if (> (get unique-accessors data) u10) "high"
                         (if (> (get unique-accessors data) u5) "medium" "low"))
      })
      none
    )
  )
)


(define-map patient-delegates
  { patient: principal, delegate: principal }
  {
    authorized-at: uint,
    expires-at: uint,
    permissions: (string-ascii 50),
    active: bool,
    actions-performed: uint
  }
)

(define-map delegate-actions
  { action-id: uint }
  {
    delegate: principal,
    patient: principal,
    action-type: (string-ascii 30),
    target-provider: principal,
    performed-at: uint
  }
)

(define-data-var total-delegates uint u0)
(define-data-var next-action-id uint u1)

(define-public (authorize-delegate 
  (delegate principal) 
  (duration uint) 
  (permissions (string-ascii 50))
)
  (let ((patient tx-sender))
    (asserts! (not (is-eq patient delegate)) ERR_SELF_ACCESS)
    (asserts! (> duration u0) ERR_INVALID_DURATION)
    (asserts! (is-none (map-get? patient-delegates { patient: patient, delegate: delegate })) ERR_DELEGATE_EXISTS)
    (map-set patient-delegates { patient: patient, delegate: delegate } {
      authorized-at: stacks-block-height,
      expires-at: (+ stacks-block-height duration),
      permissions: permissions,
      active: true,
      actions-performed: u0
    })
    (var-set total-delegates (+ (var-get total-delegates) u1))
    (ok true)
  )
)

(define-public (revoke-delegate (delegate principal))
  (let (
    (patient tx-sender)
    (delegate-key { patient: patient, delegate: delegate })
    (delegate-data (unwrap! (map-get? patient-delegates delegate-key) ERR_NOT_DELEGATE))
  )
    (map-set patient-delegates delegate-key (merge delegate-data { active: false }))
    (ok true)
  )
)

(define-public (delegate-grant-consent (patient principal) (requester principal))
  (let (
    (delegate tx-sender)
    (delegate-key { patient: patient, delegate: delegate })
    (delegate-data (unwrap! (map-get? patient-delegates delegate-key) ERR_NOT_DELEGATE))
    (request-key { patient: patient, requester: requester })
    (request-data (unwrap! (map-get? consent-requests request-key) ERR_NOT_FOUND))
  )
    (asserts! (get active delegate-data) ERR_UNAUTHORIZED)
    (asserts! (< stacks-block-height (get expires-at delegate-data)) ERR_DELEGATE_EXPIRED)
    (asserts! (is-eq (get status request-data) "pending") ERR_UNAUTHORIZED)
    (map-set consent-requests request-key (merge request-data { status: "approved" }))
    (map-set active-consents { patient: patient, accessor: requester } {
      granted-at: stacks-block-height,
      expires-at: (get expires-at request-data),
      purpose: (get purpose request-data),
      access-count: u0,
      record-types: (get record-types request-data)
    })
    (ok true)
  )
)

(define-read-only (get-delegate-status (patient principal) (delegate principal))
  (map-get? patient-delegates { patient: patient, delegate: delegate })
)

(define-read-only (check-delegate-validity (patient principal) (delegate principal))
  (match (map-get? patient-delegates { patient: patient, delegate: delegate })
    data (and (get active data) (< stacks-block-height (get expires-at data)))
    false
  )
)

(define-map consent-templates
  { patient: principal, template-id: uint }
  {
    template-name: (string-ascii 30),
    default-duration: uint,
    default-record-types: (list 5 (string-ascii 20)),
    auto-approve: bool,
    created-at: uint,
    active: bool,
    usage-count: uint
  }
)

(define-map patient-template-count
  { patient: principal }
  { count: uint }
)

(define-data-var total-templates uint u0)

(define-public (create-consent-template
  (template-name (string-ascii 30))
  (duration uint)
  (record-types (list 5 (string-ascii 20)))
  (auto-approve bool)
)
  (let (
    (patient tx-sender)
    (template-id (default-to u0 (get count (map-get? patient-template-count { patient: patient }))))
  )
    (asserts! (is-some (map-get? patients patient)) ERR_NOT_FOUND)
    (asserts! (> duration u0) ERR_INVALID_DURATION)
    (map-set consent-templates { patient: patient, template-id: template-id } {
      template-name: template-name,
      default-duration: duration,
      default-record-types: record-types,
      auto-approve: auto-approve,
      created-at: stacks-block-height,
      active: true,
      usage-count: u0
    })
    (map-set patient-template-count { patient: patient } { count: (+ template-id u1) })
    (var-set total-templates (+ (var-get total-templates) u1))
    (ok template-id)
  )
)

(define-public (apply-template-to-request (requester principal) (template-id uint))
  (let (
    (patient tx-sender)
    (template-key { patient: patient, template-id: template-id })
    (template (unwrap! (map-get? consent-templates template-key) ERR_TEMPLATE_NOT_FOUND))
    (request-key { patient: patient, requester: requester })
    (request-data (unwrap! (map-get? consent-requests request-key) ERR_NOT_FOUND))
  )
    (asserts! (get active template) ERR_TEMPLATE_INACTIVE)
    (asserts! (is-eq (get status request-data) "pending") ERR_UNAUTHORIZED)
    (map-set consent-requests request-key (merge request-data { status: "approved" }))
    (map-set active-consents { patient: patient, accessor: requester } {
      granted-at: stacks-block-height,
      expires-at: (+ stacks-block-height (get default-duration template)),
      purpose: (get purpose request-data),
      access-count: u0,
      record-types: (get default-record-types template)
    })
    (map-set consent-templates template-key 
      (merge template { usage-count: (+ (get usage-count template) u1) }))
    (var-set total-consents (+ (var-get total-consents) u1))
    (ok true)
  )
)

(define-public (toggle-template (template-id uint))
  (let (
    (patient tx-sender)
    (template-key { patient: patient, template-id: template-id })
    (template (unwrap! (map-get? consent-templates template-key) ERR_TEMPLATE_NOT_FOUND))
  )
    (map-set consent-templates template-key 
      (merge template { active: (not (get active template)) }))
    (ok true)
  )
)

(define-read-only (get-consent-template (patient principal) (template-id uint))
  (map-get? consent-templates { patient: patient, template-id: template-id })
)

(define-read-only (get-patient-template-count (patient principal))
  (default-to u0 (get count (map-get? patient-template-count { patient: patient })))
)