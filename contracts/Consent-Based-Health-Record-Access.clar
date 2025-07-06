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
