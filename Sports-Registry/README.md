# Sports Complex Booking & Management System

A comprehensive decentralized platform built on the Stacks blockchain for managing sports facilities, reservations, payments, maintenance, and user profiles with automated revenue tracking and facility availability management.

## Overview

This smart contract provides a complete solution for sports facility management, enabling facility owners to register their venues, customers to make bookings, and administrators to oversee the entire ecosystem. The platform includes automated payment processing, maintenance scheduling, and comprehensive analytics.

## Features

### Core Functionality
- **Facility Registration & Management**: Register and manage sports facilities with detailed information
- **Booking & Reservations**: Create, manage, and track facility bookings with automated scheduling
- **Payment Processing**: Secure STX-based payments with automatic fee distribution
- **Customer Profiles**: Comprehensive user profile management with membership tiers
- **Maintenance Scheduling**: Track and schedule facility maintenance activities
- **Revenue Analytics**: Automated revenue tracking and reporting by facility and period

### Key Benefits
- Decentralized facility management
- Automated payment processing with platform fees
- Real-time availability checking
- Comprehensive booking lifecycle management
- Maintenance tracking and scheduling
- Revenue analytics and reporting

## Contract Architecture

### Data Structures

#### Sports Facility Registry
Stores comprehensive facility information including:
- Facility details (name, description, location)
- Capacity and pricing information
- Owner details and amenities
- Operational status and timestamps

#### Booking Reservation Registry
Manages all booking reservations with:
- Facility and customer associations
- Time slot information
- Payment and status tracking
- Special requests handling

#### Customer Profile Registry
Maintains customer information including:
- Personal details and contact information
- Membership tier management
- Booking history and statistics

#### Maintenance Records
Tracks facility maintenance with:
- Maintenance categories and descriptions
- Scheduling and completion tracking
- Cost estimation and worker assignment

### Key Constants

#### Business Logic
- **Platform Fee**: 2.5% (250 basis points) with 10% maximum
- **Maximum Booking Duration**: 12 hours
- **Cancellation Notice**: 2 hours minimum
- **Check-in Window**: 30 minutes before/after start time
- **Refund Percentage**: 90% on valid cancellations

#### Error Handling
Comprehensive error codes for:
- Authentication and authorization (100-102)
- Booking and scheduling conflicts (105-110)
- Data validation errors (111-114)

## Functions Reference

### Facility Management

#### `register-new-sports-facility`
Register a new sports facility with complete details.

**Parameters:**
- `facility-name` (string-ascii 100): Name of the facility
- `facility-description` (string-ascii 500): Detailed description
- `physical-location` (string-ascii 200): Physical address
- `maximum-capacity` (uint): Maximum occupancy
- `hourly-rental-rate` (uint): Rate per hour in microSTX
- `available-amenities` (list 10 (string-ascii 50)): List of amenities

**Returns:** `(response uint uint)` - New facility ID on success

#### `update-existing-facility-information`
Update facility information (owner only).

**Parameters:** Same as registration
**Returns:** `(response bool uint)` - Success status

#### `toggle-facility-operational-status`
Enable/disable facility availability (owner only).

**Parameters:**
- `facility-identifier` (uint): Facility ID

**Returns:** `(response bool uint)` - New status

### Customer Management

#### `create-new-customer-profile`
Create a new customer profile.

**Parameters:**
- `customer-full-name` (string-ascii 100): Full name
- `customer-email-address` (string-ascii 100): Email address
- `customer-phone-number` (string-ascii 20): Phone number

**Returns:** `(response bool uint)` - Success status

#### `update-existing-customer-profile`
Update existing customer profile information.

**Parameters:** Same as profile creation
**Returns:** `(response bool uint)` - Success status

### Booking Management

#### `create-facility-booking-reservation`
Create a new booking reservation.

**Parameters:**
- `facility-identifier` (uint): Target facility ID
- `reservation-start-time` (uint): Start timestamp
- `booking-duration-hours` (uint): Duration in hours
- `customer-special-requests` (string-ascii 300): Special requests

**Returns:** `(response uint uint)` - New reservation ID

#### `process-booking-payment`
Process payment for a confirmed booking.

**Parameters:**
- `reservation-identifier` (uint): Booking ID

**Returns:** `(response bool uint)` - Payment status

#### `cancel-existing-booking-reservation`
Cancel a booking with automatic refund processing.

**Parameters:**
- `reservation-identifier` (uint): Booking ID

**Returns:** `(response bool uint)` - Cancellation status

#### `process-customer-check-in`
Check in for a confirmed booking within the check-in window.

**Parameters:**
- `reservation-identifier` (uint): Booking ID

**Returns:** `(response bool uint)` - Check-in status

#### `complete-booking-session`
Mark a booking as completed after the session ends.

**Parameters:**
- `reservation-identifier` (uint): Booking ID

**Returns:** `(response bool uint)` - Completion status

### Maintenance Management

#### `schedule-facility-maintenance`
Schedule maintenance for a facility (owner only).

**Parameters:**
- `facility-identifier` (uint): Facility ID
- `maintenance-category` (string-ascii 50): Category type
- `maintenance-description` (string-ascii 500): Description
- `scheduled-maintenance-date` (uint): Scheduled timestamp
- `estimated-maintenance-cost` (uint): Cost estimate

**Returns:** `(response uint uint)` - Maintenance record ID

#### `update-maintenance-record-status`
Update maintenance record status and assignments.

**Parameters:**
- `maintenance-record-id` (uint): Maintenance ID
- `new-maintenance-status` (string-ascii 20): New status
- `assigned-maintenance-worker` (optional principal): Worker address

**Returns:** `(response bool uint)` - Update status

### Query Functions (Read-Only)

#### `get-facility-information`
Retrieve complete facility information.

**Parameters:**
- `facility-identifier` (uint): Facility ID

**Returns:** Facility data or none

#### `get-booking-reservation-details`
Get booking reservation details.

**Parameters:**
- `reservation-identifier` (uint): Booking ID

**Returns:** Booking data or none

#### `get-customer-profile-information`
Retrieve customer profile data.

**Parameters:**
- `customer-address` (principal): Customer address

**Returns:** Profile data or none

#### `check-facility-time-slot-availability`
Check availability for specific time slots.

**Parameters:**
- `facility-identifier` (uint): Facility ID
- `booking-date` (uint): Date timestamp
- `start-hour` (uint): Start hour (0-23)
- `end-hour` (uint): End hour (0-23)

**Returns:** `(response bool uint)` - Availability status

#### `calculate-total-booking-cost`
Calculate total cost including platform fees.

**Parameters:**
- `facility-identifier` (uint): Facility ID
- `duration-hours` (uint): Booking duration

**Returns:** `(response uint uint)` - Total cost

#### `get-facility-revenue-analytics`
Get revenue analytics for a facility and period.

**Parameters:**
- `facility-identifier` (uint): Facility ID
- `reporting-period` (uint): Period (YYYYMM format)

**Returns:** Revenue and booking statistics

### Administrative Functions

#### `configure-platform-fee-rate`
Update platform fee rate (administrator only).

**Parameters:**
- `new-fee-rate` (uint): New fee rate in basis points

**Returns:** `(response bool uint)` - Success status

#### `authorize-new-facility-owner`
Authorize a new facility owner (administrator only).

**Parameters:**
- `owner-address` (principal): Owner address

**Returns:** `(response bool uint)` - Authorization status

## Booking Lifecycle

1. **Registration**: Customer creates profile and facility owner registers facility
2. **Reservation**: Customer creates booking reservation with time slot selection
3. **Payment**: Customer processes payment, funds distributed to owner and platform
4. **Check-in**: Customer checks in during the designated window
5. **Completion**: Session completes and booking is marked as finished
6. **Analytics**: Revenue and booking statistics are automatically updated

## Maintenance Categories

The system supports five maintenance categories:
- **routine**: Regular scheduled maintenance
- **repair**: Emergency or necessary repairs
- **upgrade**: Facility improvements and upgrades
- **inspection**: Safety and compliance inspections
- **cleaning**: Deep cleaning and sanitization

## Membership Tiers

- **basic**: Default tier for new customers
- **premium**: Enhanced benefits (implementation-dependent)
- **vip**: Highest tier with maximum benefits

## Security Features

- Owner-only functions for facility management
- Customer-only access to personal bookings
- Administrator controls for platform settings
- Comprehensive input validation
- Time-based access controls for check-ins
- Automatic refund processing with fraud protection

## Error Handling

The contract includes comprehensive error handling with specific error codes:
- Authentication errors (100-102)
- Booking conflicts (105-110)
- Validation errors (111-114)

## Usage Examples

### Register a Facility
```clarity
(contract-call? .sports-booking register-new-sports-facility
  "Downtown Tennis Court"
  "Professional tennis court with lighting"
  "123 Main St, Downtown"
  u4
  u50000000
  (list "lighting" "equipment" "parking"))
```

### Create a Booking
```clarity
(contract-call? .sports-booking create-facility-booking-reservation
  u1
  u1640995200  ;; Unix timestamp
  u2           ;; 2 hours
  "Need extra equipment")
```

### Process Payment
```clarity
(contract-call? .sports-booking process-booking-payment u1)
```