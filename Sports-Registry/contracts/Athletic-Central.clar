;; Sports Complex Booking & Management System Smart Contract
;; A comprehensive decentralized platform for managing sports facilities, 
;; reservations, payments, maintenance, and user profiles with automated 
;; revenue tracking and facility availability management

;; CONSTANTS AND ERROR DEFINITIONS

(define-constant contract-administrator tx-sender)

;; Error Constants - Authentication & Authorization
(define-constant ERR-UNAUTHORIZED-ACCESS (err u100))
(define-constant ERR-RESOURCE-NOT-FOUND (err u101))
(define-constant ERR-RESOURCE-ALREADY-EXISTS (err u102))
(define-constant ERR-INVALID-PARAMETERS (err u103))
(define-constant ERR-INSUFFICIENT-BALANCE (err u104))

;; Error Constants - Booking & Scheduling
(define-constant ERR-BOOKING-TIME-CONFLICT (err u105))
(define-constant ERR-BOOKING-ALREADY-EXPIRED (err u106))
(define-constant ERR-FACILITY-NOT-AVAILABLE (err u107))
(define-constant ERR-INVALID-TIME-SLOT (err u108))
(define-constant ERR-USER-ALREADY-CHECKED-IN (err u109))
(define-constant ERR-USER-NOT-CHECKED-IN (err u110))

;; Error Constants - Data Validation
(define-constant ERR-INVALID-STRING-FORMAT (err u111))
(define-constant ERR-INVALID-EMAIL-FORMAT (err u112))
(define-constant ERR-INVALID-PHONE-FORMAT (err u113))
(define-constant ERR-INVALID-MAINTENANCE-TYPE (err u114))

;; Business Logic Constants
(define-constant default-platform-fee-percentage u250) ;; 2.5% in basis points
(define-constant maximum-booking-duration-hours u12)
(define-constant minimum-cancellation-notice-seconds u7200) ;; 2 hours
(define-constant check-in-window-seconds u1800) ;; 30 minutes
(define-constant refund-percentage u90) ;; 90% refund on cancellation
(define-constant maximum-platform-fee-percentage u1000) ;; 10% maximum
(define-constant seconds-per-hour u3600)
(define-constant seconds-per-day u86400)
(define-constant approximate-seconds-per-month u2629746)

;; STATE VARIABLES

(define-data-var next-available-facility-id uint u1)
(define-data-var next-available-booking-id uint u1)
(define-data-var next-available-maintenance-id uint u1)
(define-data-var current-platform-fee-rate uint default-platform-fee-percentage)

;; DATA STRUCTURES

;; Sports Facility Information
(define-map sports-facility-registry
    { facility-identifier: uint }
    {
        facility-name: (string-ascii 100),
        facility-description: (string-ascii 500),
        physical-location: (string-ascii 200),
        maximum-capacity: uint,
        hourly-rental-rate: uint,
        facility-owner-address: principal,
        is-currently-active: bool,
        available-amenities: (list 10 (string-ascii 50)),
        creation-timestamp: uint,
        last-modification-timestamp: uint
    }
)

;; Booking and Reservation Records
(define-map booking-reservation-registry
    { reservation-identifier: uint }
    {
        associated-facility-id: uint,
        customer-address: principal,
        reservation-start-time: uint,
        reservation-end-time: uint,
        total-reservation-cost: uint,
        current-reservation-status: (string-ascii 20), ;; "pending", "confirmed", "checked-in", "completed", "cancelled"
        payment-transaction-status: (string-ascii 20), ;; "pending", "paid", "refunded"
        reservation-creation-time: uint,
        last-status-update-time: uint,
        customer-special-requests: (string-ascii 300)
    }
)

;; Maintenance and Service Records
(define-map facility-maintenance-records
    { maintenance-record-id: uint }
    {
        target-facility-id: uint,
        maintenance-category: (string-ascii 50), ;; "routine", "repair", "upgrade", "inspection", "cleaning"
        maintenance-description: (string-ascii 500),
        scheduled-maintenance-date: uint,
        actual-completion-date: (optional uint),
        estimated-maintenance-cost: uint,
        current-maintenance-status: (string-ascii 20), ;; "scheduled", "in-progress", "completed", "cancelled"
        assigned-maintenance-worker: (optional principal),
        maintenance-creator-address: principal,
        maintenance-record-creation-time: uint
    }
)

;; Customer Profile Management
(define-map customer-profile-registry
    { customer-address: principal }
    {
        customer-full-name: (string-ascii 100),
        customer-email-address: (string-ascii 100),
        customer-phone-number: (string-ascii 20),
        membership-tier-level: (string-ascii 20), ;; "basic", "premium", "vip"
        total-completed-bookings: uint,
        profile-creation-timestamp: uint,
        is-profile-active: bool
    }
)

;; Facility Owner Authorization
(define-map authorized-facility-owners
    { owner-address: principal }
    { 
        is-owner-approved: bool, 
        total-owned-facilities: uint 
    }
)

;; Time Slot Availability Tracking
(define-map facility-time-slot-availability
    { facility-identifier: uint, booking-date: uint, time-slot-hour: uint }
    { 
        is-time-slot-available: bool, 
        associated-booking-id: (optional uint) 
    }
)

;; Revenue Analytics and Reporting
(define-map facility-financial-analytics
    { facility-identifier: uint, reporting-period: uint } ;; period as YYYYMM
    { 
        total-period-revenue: uint, 
        total-period-bookings: uint 
    }
)

;; INPUT VALIDATION FUNCTIONS

(define-private (validate-ascii-string-format (input-string (string-ascii 1000)))
    (let ((string-length (len input-string)))
        (and (> string-length u0)
             (<= string-length u1000))
    )
)

(define-private (validate-phone-number-format (phone-number (string-ascii 20)))
    (and (> (len phone-number) u0)
         (<= (len phone-number) u20)
         (validate-ascii-string-format phone-number))
)

(define-private (validate-email-address-format (email-address (string-ascii 100)))
    (and (> (len email-address) u4) ;; Minimum "a@b"
         (<= (len email-address) u100)
         (is-some (index-of email-address "@"))
         (is-some (index-of email-address "."))
         (validate-ascii-string-format email-address))
)

(define-private (validate-maintenance-category-type (maintenance-type (string-ascii 50)))
    (or (is-eq maintenance-type "routine")
        (is-eq maintenance-type "repair")
        (is-eq maintenance-type "upgrade")
        (is-eq maintenance-type "inspection")
        (is-eq maintenance-type "cleaning"))
)

(define-private (validate-facility-name-input (facility-name (string-ascii 100)))
    (if (and (> (len facility-name) u0) (<= (len facility-name) u100))
        (ok facility-name)
        ERR-INVALID-STRING-FORMAT)
)

(define-private (validate-facility-description-input (facility-description (string-ascii 500)))
    (if (and (>= (len facility-description) u0) (<= (len facility-description) u500))
        (ok facility-description)
        ERR-INVALID-STRING-FORMAT)
)

(define-private (validate-location-address-input (location-address (string-ascii 200)))
    (if (and (>= (len location-address) u0) (<= (len location-address) u200))
        (ok location-address)
        ERR-INVALID-STRING-FORMAT)
)

(define-private (validate-phone-number-input (phone-number (string-ascii 20)))
    (if (and (> (len phone-number) u0) (<= (len phone-number) u20))
        (ok phone-number)
        ERR-INVALID-STRING-FORMAT)
)

(define-private (validate-email-address-input (email-address (string-ascii 100)))
    (if (and (> (len email-address) u0) (<= (len email-address) u100))
        (ok email-address)
        ERR-INVALID-STRING-FORMAT)
)

(define-private (validate-special-requests-input (special-requests (string-ascii 300)))
    (if (and (>= (len special-requests) u0) (<= (len special-requests) u300))
        (ok special-requests)
        ERR-INVALID-STRING-FORMAT)
)

(define-private (validate-amenities-list (amenities-list (list 10 (string-ascii 50))))
    (fold check-individual-amenity-item amenities-list true)
)

(define-private (check-individual-amenity-item (amenity-item (string-ascii 50)) (validation-accumulator bool))
    (and validation-accumulator 
         (validate-ascii-string-format amenity-item) 
         (<= (len amenity-item) u50))
)

;; READ-ONLY QUERY FUNCTIONS

(define-read-only (get-facility-information (facility-identifier uint))
    (map-get? sports-facility-registry { facility-identifier: facility-identifier })
)

(define-read-only (get-booking-reservation-details (reservation-identifier uint))
    (map-get? booking-reservation-registry { reservation-identifier: reservation-identifier })
)

(define-read-only (get-maintenance-record-details (maintenance-record-id uint))
    (map-get? facility-maintenance-records { maintenance-record-id: maintenance-record-id })
)

(define-read-only (get-customer-profile-information (customer-address principal))
    (map-get? customer-profile-registry { customer-address: customer-address })
)

(define-read-only (verify-facility-owner-authorization (owner-address principal))
    (default-to false 
        (get is-owner-approved 
             (map-get? authorized-facility-owners { owner-address: owner-address })))
)

(define-read-only (get-current-platform-fee-rate)
    (var-get current-platform-fee-rate)
)

(define-read-only (check-facility-time-slot-availability 
                   (facility-identifier uint) 
                   (booking-date uint) 
                   (start-hour uint) 
                   (end-hour uint))
    (if (and (< start-hour end-hour) (<= end-hour u24))
        (ok (check-individual-time-slot facility-identifier booking-date start-hour))
        (ok false))
)

(define-read-only (get-facility-revenue-analytics (facility-identifier uint) (reporting-period uint))
    (default-to { total-period-revenue: u0, total-period-bookings: u0 }
        (map-get? facility-financial-analytics 
                 { facility-identifier: facility-identifier, reporting-period: reporting-period }))
)

(define-read-only (calculate-total-booking-cost (facility-identifier uint) (duration-hours uint))
    (match (get-facility-information facility-identifier)
        facility-data 
            (let ((hourly-rate (get hourly-rental-rate facility-data))
                  (base-rental-cost (* hourly-rate duration-hours))
                  (platform-service-fee (/ (* base-rental-cost (var-get current-platform-fee-rate)) u10000)))
                (ok (+ base-rental-cost platform-service-fee)))
        ERR-RESOURCE-NOT-FOUND)
)

;; PRIVATE UTILITY FUNCTIONS

(define-private (check-individual-time-slot (facility-identifier uint) (booking-date uint) (time-hour uint))
    (default-to true 
        (get is-time-slot-available 
             (map-get? facility-time-slot-availability 
                      { facility-identifier: facility-identifier, 
                        booking-date: booking-date, 
                        time-slot-hour: time-hour })))
)

(define-private (update-time-slot-availability-status 
                 (facility-identifier uint) 
                 (booking-date uint) 
                 (time-hour uint) 
                 (availability-status bool) 
                 (associated-booking-id (optional uint)))
    (map-set facility-time-slot-availability
        { facility-identifier: facility-identifier, 
          booking-date: booking-date, 
          time-slot-hour: time-hour }
        { is-time-slot-available: availability-status, 
          associated-booking-id: associated-booking-id })
)

(define-private (extract-date-from-timestamp (timestamp uint))
    ;; Simplified date extraction (convert to days since epoch)
    (/ timestamp seconds-per-day)
)

(define-private (extract-hour-from-timestamp (timestamp uint))
    (mod (/ timestamp seconds-per-hour) u24) ;; Extract hour of day (0-23)
)

(define-private (update-facility-revenue-statistics (facility-identifier uint) (revenue-amount uint))
    (let ((current-reporting-period (/ (unwrap-panic (get-block-info? time (- block-height u1))) 
                                       approximate-seconds-per-month))
          (existing-revenue-stats (get-facility-revenue-analytics facility-identifier current-reporting-period)))
        (map-set facility-financial-analytics
            { facility-identifier: facility-identifier, reporting-period: current-reporting-period }
            { 
                total-period-revenue: (+ (get total-period-revenue existing-revenue-stats) revenue-amount),
                total-period-bookings: (+ (get total-period-bookings existing-revenue-stats) u1)
            }))
)

;; FACILITY MANAGEMENT FUNCTIONS

(define-public (register-new-sports-facility 
                (facility-name (string-ascii 100))
                (facility-description (string-ascii 500))
                (physical-location (string-ascii 200))
                (maximum-capacity uint)
                (hourly-rental-rate uint)
                (available-amenities (list 10 (string-ascii 50))))
    (let ((new-facility-id (var-get next-available-facility-id))
          (current-timestamp (unwrap-panic (get-block-info? time (- block-height u1)))))
        
        ;; Validate all input parameters
        (asserts! (> maximum-capacity u0) ERR-INVALID-PARAMETERS)
        (asserts! (> hourly-rental-rate u0) ERR-INVALID-PARAMETERS)
        (asserts! (> (len facility-name) u0) ERR-INVALID-PARAMETERS)
        (asserts! (<= (len facility-name) u100) ERR-INVALID-PARAMETERS)
        (asserts! (<= (len facility-description) u500) ERR-INVALID-PARAMETERS)
        (asserts! (<= (len physical-location) u200) ERR-INVALID-PARAMETERS)
        (asserts! (validate-amenities-list available-amenities) ERR-INVALID-STRING-FORMAT)
        
        ;; Create facility record
        (map-set sports-facility-registry
            { facility-identifier: new-facility-id }
            {
                facility-name: facility-name,
                facility-description: facility-description,
                physical-location: physical-location,
                maximum-capacity: maximum-capacity,
                hourly-rental-rate: hourly-rental-rate,
                facility-owner-address: tx-sender,
                is-currently-active: true,
                available-amenities: available-amenities,
                creation-timestamp: current-timestamp,
                last-modification-timestamp: current-timestamp
            })
        
        ;; Update facility owner registry
        (let ((current-owner-data (default-to { is-owner-approved: true, total-owned-facilities: u0 } 
                                             (map-get? authorized-facility-owners { owner-address: tx-sender }))))
            (map-set authorized-facility-owners
                { owner-address: tx-sender }
                { 
                    is-owner-approved: (get is-owner-approved current-owner-data),
                    total-owned-facilities: (+ (get total-owned-facilities current-owner-data) u1)
                }))
        
        (var-set next-available-facility-id (+ new-facility-id u1))
        (ok new-facility-id))
)

(define-public (update-existing-facility-information 
                (facility-identifier uint)
                (facility-name (string-ascii 100))
                (facility-description (string-ascii 500))
                (physical-location (string-ascii 200))
                (maximum-capacity uint)
                (hourly-rental-rate uint)
                (available-amenities (list 10 (string-ascii 50))))
    (let ((existing-facility-data (unwrap! (get-facility-information facility-identifier) ERR-RESOURCE-NOT-FOUND))
          (current-timestamp (unwrap-panic (get-block-info? time (- block-height u1)))))
        
        (asserts! (is-eq tx-sender (get facility-owner-address existing-facility-data)) ERR-UNAUTHORIZED-ACCESS)
        (asserts! (> maximum-capacity u0) ERR-INVALID-PARAMETERS)
        (asserts! (> hourly-rental-rate u0) ERR-INVALID-PARAMETERS)
        (asserts! (> (len facility-name) u0) ERR-INVALID-PARAMETERS)
        (asserts! (<= (len facility-name) u100) ERR-INVALID-PARAMETERS)
        (asserts! (<= (len facility-description) u500) ERR-INVALID-PARAMETERS)
        (asserts! (<= (len physical-location) u200) ERR-INVALID-PARAMETERS)
        (asserts! (validate-amenities-list available-amenities) ERR-INVALID-STRING-FORMAT)
        
        (map-set sports-facility-registry
            { facility-identifier: facility-identifier }
            (merge existing-facility-data
                {
                    facility-name: facility-name,
                    facility-description: facility-description,
                    physical-location: physical-location,
                    maximum-capacity: maximum-capacity,
                    hourly-rental-rate: hourly-rental-rate,
                    available-amenities: available-amenities,
                    last-modification-timestamp: current-timestamp
                }))
        (ok true))
)

(define-public (toggle-facility-operational-status (facility-identifier uint))
    (let ((existing-facility-data (unwrap! (get-facility-information facility-identifier) ERR-RESOURCE-NOT-FOUND))
          (current-timestamp (unwrap-panic (get-block-info? time (- block-height u1)))))
        
        (asserts! (is-eq tx-sender (get facility-owner-address existing-facility-data)) ERR-UNAUTHORIZED-ACCESS)
        
        (map-set sports-facility-registry
            { facility-identifier: facility-identifier }
            (merge existing-facility-data
                {
                    is-currently-active: (not (get is-currently-active existing-facility-data)),
                    last-modification-timestamp: current-timestamp
                }))
        (ok (not (get is-currently-active existing-facility-data))))
)

;; CUSTOMER PROFILE MANAGEMENT FUNCTIONS

(define-public (create-new-customer-profile 
                (customer-full-name (string-ascii 100))
                (customer-email-address (string-ascii 100))
                (customer-phone-number (string-ascii 20)))
    (let ((current-timestamp (unwrap-panic (get-block-info? time (- block-height u1)))))
        
        (asserts! (is-none (get-customer-profile-information tx-sender)) ERR-RESOURCE-ALREADY-EXISTS)
        (asserts! (> (len customer-full-name) u0) ERR-INVALID-PARAMETERS)
        (asserts! (<= (len customer-full-name) u100) ERR-INVALID-PARAMETERS)
        (asserts! (<= (len customer-email-address) u100) ERR-INVALID-PARAMETERS)
        (asserts! (<= (len customer-phone-number) u20) ERR-INVALID-PARAMETERS)
        (asserts! (validate-email-address-format customer-email-address) ERR-INVALID-EMAIL-FORMAT)
        (asserts! (validate-phone-number-format customer-phone-number) ERR-INVALID-PHONE-FORMAT)
        
        (map-set customer-profile-registry
            { customer-address: tx-sender }
            {
                customer-full-name: customer-full-name,
                customer-email-address: customer-email-address,
                customer-phone-number: customer-phone-number,
                membership-tier-level: "basic",
                total-completed-bookings: u0,
                profile-creation-timestamp: current-timestamp,
                is-profile-active: true
            })
        (ok true))
)

(define-public (update-existing-customer-profile 
                (customer-full-name (string-ascii 100))
                (customer-email-address (string-ascii 100))
                (customer-phone-number (string-ascii 20)))
    (let ((existing-profile-data (unwrap! (get-customer-profile-information tx-sender) ERR-RESOURCE-NOT-FOUND)))
        
        (asserts! (get is-profile-active existing-profile-data) ERR-UNAUTHORIZED-ACCESS)
        (asserts! (> (len customer-full-name) u0) ERR-INVALID-PARAMETERS)
        (asserts! (<= (len customer-full-name) u100) ERR-INVALID-PARAMETERS)
        (asserts! (<= (len customer-email-address) u100) ERR-INVALID-PARAMETERS)
        (asserts! (<= (len customer-phone-number) u20) ERR-INVALID-PARAMETERS)
        (asserts! (validate-email-address-format customer-email-address) ERR-INVALID-EMAIL-FORMAT)
        (asserts! (validate-phone-number-format customer-phone-number) ERR-INVALID-PHONE-FORMAT)
        
        (map-set customer-profile-registry
            { customer-address: tx-sender }
            (merge existing-profile-data
                {
                    customer-full-name: customer-full-name,
                    customer-email-address: customer-email-address,
                    customer-phone-number: customer-phone-number
                }))
        (ok true))
)

;; BOOKING AND RESERVATION MANAGEMENT FUNCTIONS

(define-public (create-facility-booking-reservation 
                (facility-identifier uint)
                (reservation-start-time uint)
                (booking-duration-hours uint)
                (customer-special-requests (string-ascii 300)))
    (let ((target-facility-data (unwrap! (get-facility-information facility-identifier) ERR-RESOURCE-NOT-FOUND))
          (reservation-end-time (+ reservation-start-time (* booking-duration-hours seconds-per-hour)))
          (new-reservation-id (var-get next-available-booking-id))
          (current-timestamp (unwrap-panic (get-block-info? time (- block-height u1))))
          (total-reservation-cost (unwrap! (calculate-total-booking-cost facility-identifier booking-duration-hours) ERR-INVALID-PARAMETERS))
          (booking-date (extract-date-from-timestamp reservation-start-time))
          (start-time-hour (extract-hour-from-timestamp reservation-start-time)))
        
        (asserts! (get is-currently-active target-facility-data) ERR-FACILITY-NOT-AVAILABLE)
        (asserts! (> reservation-start-time current-timestamp) ERR-INVALID-TIME-SLOT)
        (asserts! (> booking-duration-hours u0) ERR-INVALID-PARAMETERS)
        (asserts! (<= booking-duration-hours maximum-booking-duration-hours) ERR-INVALID-PARAMETERS)
        (asserts! (<= (len customer-special-requests) u300) ERR-INVALID-PARAMETERS)
        
        ;; Check time slot availability
        (asserts! (check-individual-time-slot facility-identifier booking-date start-time-hour) ERR-BOOKING-TIME-CONFLICT)
        
        ;; Create booking reservation record
        (map-set booking-reservation-registry
            { reservation-identifier: new-reservation-id }
            {
                associated-facility-id: facility-identifier,
                customer-address: tx-sender,
                reservation-start-time: reservation-start-time,
                reservation-end-time: reservation-end-time,
                total-reservation-cost: total-reservation-cost,
                current-reservation-status: "pending",
                payment-transaction-status: "pending",
                reservation-creation-time: current-timestamp,
                last-status-update-time: current-timestamp,
                customer-special-requests: customer-special-requests
            })
        
        ;; Reserve the time slot
        (update-time-slot-availability-status facility-identifier booking-date start-time-hour false (some new-reservation-id))
        
        (var-set next-available-booking-id (+ new-reservation-id u1))
        (ok new-reservation-id))
)

(define-public (process-booking-payment (reservation-identifier uint))
    (let ((booking-reservation-data (unwrap! (get-booking-reservation-details reservation-identifier) ERR-RESOURCE-NOT-FOUND)))
        
        (asserts! (is-eq tx-sender (get customer-address booking-reservation-data)) ERR-UNAUTHORIZED-ACCESS)
        (asserts! (is-eq (get payment-transaction-status booking-reservation-data) "pending") ERR-INVALID-PARAMETERS)
        (asserts! (>= (stx-get-balance tx-sender) (get total-reservation-cost booking-reservation-data)) ERR-INSUFFICIENT-BALANCE)
        
        (let ((target-facility-data (unwrap! (get-facility-information (get associated-facility-id booking-reservation-data)) ERR-RESOURCE-NOT-FOUND))
              (platform-service-fee (/ (* (get total-reservation-cost booking-reservation-data) (var-get current-platform-fee-rate)) u10000))
              (facility-owner-payment (- (get total-reservation-cost booking-reservation-data) platform-service-fee)))
            
            ;; Transfer payment to facility owner
            (try! (stx-transfer? facility-owner-payment tx-sender (get facility-owner-address target-facility-data)))
            
            ;; Transfer platform fee to contract administrator
            (try! (stx-transfer? platform-service-fee tx-sender contract-administrator))
            
            ;; Update booking reservation status
            (map-set booking-reservation-registry
                { reservation-identifier: reservation-identifier }
                (merge booking-reservation-data
                    {
                        payment-transaction-status: "paid",
                        current-reservation-status: "confirmed",
                        last-status-update-time: (unwrap-panic (get-block-info? time (- block-height u1)))
                    }))
            
            ;; Update revenue analytics
            (update-facility-revenue-statistics (get associated-facility-id booking-reservation-data) 
                                               (get total-reservation-cost booking-reservation-data))
            
            ;; Update customer profile statistics
            (let ((customer-profile-data (default-to 
                                            { customer-full-name: "", customer-email-address: "", customer-phone-number: "", 
                                              membership-tier-level: "basic", total-completed-bookings: u0, 
                                              profile-creation-timestamp: u0, is-profile-active: true }
                                            (get-customer-profile-information tx-sender))))
                (map-set customer-profile-registry
                    { customer-address: tx-sender }
                    (merge customer-profile-data
                        { total-completed-bookings: (+ (get total-completed-bookings customer-profile-data) u1) })))
            
            (ok true)))
)

(define-public (cancel-existing-booking-reservation (reservation-identifier uint))
    (let ((booking-reservation-data (unwrap! (get-booking-reservation-details reservation-identifier) ERR-RESOURCE-NOT-FOUND))
          (current-timestamp (unwrap-panic (get-block-info? time (- block-height u1)))))
        
        (asserts! (is-eq tx-sender (get customer-address booking-reservation-data)) ERR-UNAUTHORIZED-ACCESS)
        (asserts! (or (is-eq (get current-reservation-status booking-reservation-data) "pending") 
                      (is-eq (get current-reservation-status booking-reservation-data) "confirmed")) ERR-INVALID-PARAMETERS)
        (asserts! (> (get reservation-start-time booking-reservation-data) 
                     (+ current-timestamp minimum-cancellation-notice-seconds)) ERR-INVALID-PARAMETERS)
        
        ;; Release the reserved time slot
        (let ((booking-date (extract-date-from-timestamp (get reservation-start-time booking-reservation-data)))
              (start-time-hour (extract-hour-from-timestamp (get reservation-start-time booking-reservation-data))))
            (update-time-slot-availability-status (get associated-facility-id booking-reservation-data) 
                                                 booking-date start-time-hour true none))
        
        ;; Process refund if payment was completed
        (if (is-eq (get payment-transaction-status booking-reservation-data) "paid")
            (let ((refund-amount (/ (* (get total-reservation-cost booking-reservation-data) refund-percentage) u100)))
                (try! (as-contract (stx-transfer? refund-amount tx-sender (get customer-address booking-reservation-data))))
                (map-set booking-reservation-registry
                    { reservation-identifier: reservation-identifier }
                    (merge booking-reservation-data
                        {
                            current-reservation-status: "cancelled",
                            payment-transaction-status: "refunded",
                            last-status-update-time: current-timestamp
                        })))
            (map-set booking-reservation-registry
                { reservation-identifier: reservation-identifier }
                (merge booking-reservation-data
                    {
                        current-reservation-status: "cancelled",
                        last-status-update-time: current-timestamp
                    })))
        (ok true))
)

(define-public (process-customer-check-in (reservation-identifier uint))
    (let ((booking-reservation-data (unwrap! (get-booking-reservation-details reservation-identifier) ERR-RESOURCE-NOT-FOUND))
          (current-timestamp (unwrap-panic (get-block-info? time (- block-height u1)))))
        
        (asserts! (is-eq tx-sender (get customer-address booking-reservation-data)) ERR-UNAUTHORIZED-ACCESS)
        (asserts! (is-eq (get current-reservation-status booking-reservation-data) "confirmed") ERR-INVALID-PARAMETERS)
        (asserts! (>= current-timestamp (- (get reservation-start-time booking-reservation-data) check-in-window-seconds)) ERR-INVALID-TIME-SLOT)
        (asserts! (<= current-timestamp (+ (get reservation-start-time booking-reservation-data) check-in-window-seconds)) ERR-INVALID-TIME-SLOT)
        
        (map-set booking-reservation-registry
            { reservation-identifier: reservation-identifier }
            (merge booking-reservation-data
                {
                    current-reservation-status: "checked-in",
                    last-status-update-time: current-timestamp
                }))
        (ok true))
)

(define-public (complete-booking-session (reservation-identifier uint))
    (let ((booking-reservation-data (unwrap! (get-booking-reservation-details reservation-identifier) ERR-RESOURCE-NOT-FOUND))
          (current-timestamp (unwrap-panic (get-block-info? time (- block-height u1)))))
        
        (asserts! (is-eq tx-sender (get customer-address booking-reservation-data)) ERR-UNAUTHORIZED-ACCESS)
        (asserts! (is-eq (get current-reservation-status booking-reservation-data) "checked-in") ERR-INVALID-PARAMETERS)
        (asserts! (>= current-timestamp (get reservation-end-time booking-reservation-data)) ERR-INVALID-TIME-SLOT)
        
        (map-set booking-reservation-registry
            { reservation-identifier: reservation-identifier }
            (merge booking-reservation-data
                {
                    current-reservation-status: "completed",
                    last-status-update-time: current-timestamp
                }))
        (ok true))
)

;; FACILITY MAINTENANCE MANAGEMENT FUNCTIONS

(define-public (schedule-facility-maintenance 
                (facility-identifier uint)
                (maintenance-category (string-ascii 50))
                (maintenance-description (string-ascii 500))
                (scheduled-maintenance-date uint)
                (estimated-maintenance-cost uint))
    (let ((target-facility-data (unwrap! (get-facility-information facility-identifier) ERR-RESOURCE-NOT-FOUND))
          (new-maintenance-id (var-get next-available-maintenance-id))
          (current-timestamp (unwrap-panic (get-block-info? time (- block-height u1)))))
        
        (asserts! (is-eq tx-sender (get facility-owner-address target-facility-data)) ERR-UNAUTHORIZED-ACCESS)
        (asserts! (> scheduled-maintenance-date current-timestamp) ERR-INVALID-PARAMETERS)
        (asserts! (> (len maintenance-description) u0) ERR-INVALID-PARAMETERS)
        (asserts! (<= (len maintenance-description) u500) ERR-INVALID-PARAMETERS)
        (asserts! (validate-maintenance-category-type maintenance-category) ERR-INVALID-MAINTENANCE-TYPE)
        (asserts! (>= estimated-maintenance-cost u0) ERR-INVALID-PARAMETERS)
        
        (map-set facility-maintenance-records
            { maintenance-record-id: new-maintenance-id }
            {
                target-facility-id: facility-identifier,
                maintenance-category: maintenance-category,
                maintenance-description: maintenance-description,
                scheduled-maintenance-date: scheduled-maintenance-date,
                actual-completion-date: none,
                estimated-maintenance-cost: estimated-maintenance-cost,
                current-maintenance-status: "scheduled",
                assigned-maintenance-worker: none,
                maintenance-creator-address: tx-sender,
                maintenance-record-creation-time: current-timestamp
            })
        
        (var-set next-available-maintenance-id (+ new-maintenance-id u1))
        (ok new-maintenance-id))
)

(define-public (update-maintenance-record-status 
                (maintenance-record-id uint)
                (new-maintenance-status (string-ascii 20))
                (assigned-maintenance-worker (optional principal)))
    (let ((maintenance-record-data (unwrap! (get-maintenance-record-details maintenance-record-id) ERR-RESOURCE-NOT-FOUND))
          (target-facility-data (unwrap! (get-facility-information (get target-facility-id maintenance-record-data)) ERR-RESOURCE-NOT-FOUND))
          (current-timestamp (unwrap-panic (get-block-info? time (- block-height u1)))))
        
        (asserts! (is-eq tx-sender (get facility-owner-address target-facility-data)) ERR-UNAUTHORIZED-ACCESS)
        (asserts! (> maintenance-record-id u0) ERR-INVALID-PARAMETERS)
        
        (map-set facility-maintenance-records
            { maintenance-record-id: maintenance-record-id }
            (merge maintenance-record-data
                {
                    current-maintenance-status: new-maintenance-status,
                    assigned-maintenance-worker: assigned-maintenance-worker,
                    actual-completion-date: (if (is-eq new-maintenance-status "completed") 
                                              (some current-timestamp) 
                                              (get actual-completion-date maintenance-record-data))
                }))
        (ok true))
)

;; ADMINISTRATIVE FUNCTIONS

(define-public (configure-platform-fee-rate (new-fee-rate uint))
    (begin
        (asserts! (is-eq tx-sender contract-administrator) ERR-UNAUTHORIZED-ACCESS)
        (asserts! (<= new-fee-rate maximum-platform-fee-percentage) ERR-INVALID-PARAMETERS)
        (var-set current-platform-fee-rate new-fee-rate)
        (ok true))
)

(define-public (authorize-new-facility-owner (owner-address principal))
    (begin
        (asserts! (is-eq tx-sender contract-administrator) ERR-UNAUTHORIZED-ACCESS)
        (asserts! (not (is-eq owner-address 'SP000000000000000000002Q6VF78)) ERR-INVALID-PARAMETERS)
        
        (let ((existing-owner-data (default-to { is-owner-approved: false, total-owned-facilities: u0 } 
                                              (map-get? authorized-facility-owners { owner-address: owner-address }))))
            (map-set authorized-facility-owners
                { owner-address: owner-address }
                (merge existing-owner-data { is-owner-approved: true })))
        (ok true))
)