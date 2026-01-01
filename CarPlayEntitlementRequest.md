# CarPlay Navigation Entitlement Request — TetraTrack

## App Name
TetraTrack

## Bundle ID
dev.dreamfold.TetraTrack

## App Store URL
(Pending first release)

## Requested Entitlement
com.apple.developer.carplay-maps

---

## Description of CarPlay Functionality

TetraTrack provides navigation guidance to equestrian and multi-sport competition venues across the United Kingdom. Competitors in tetrathlon, triathlon, eventing, and show jumping need to arrive at specific rural venues by strict discipline start times — arriving late results in elimination.

The CarPlay experience provides:

1. **Point-of-Interest navigation to competition venues** — Upcoming competitions are displayed as annotated pins on a map using `CPPointOfInterestTemplate`, each showing the venue name, first discipline start time, and estimated travel time from the driver's current location.

2. **Time-aware departure guidance** — For each competition, the app calculates the recommended departure time based on real-time travel estimates to the venue, factoring in the competitor's first discipline start time. This is displayed as a "leave by" time on the competition list.

3. **Venue route initiation** — Tapping a competition venue opens route guidance via `MKMapItem.openMaps()`, providing turn-by-turn directions to the venue coordinates.

4. **Discipline schedule at a glance** — Each venue listing shows the day's discipline start times (e.g. Swimming 09:00, Shooting 10:30, Running 13:00, Riding 14:30), so drivers can confirm their schedule without picking up their phone.

## Why CarPlay Is Essential for This Use Case

### Rural venue accessibility
Equestrian competition venues are predominantly located at rural estates, farms, and countryside showgrounds (e.g. Badminton House, Burghley House, Chatsworth). These locations frequently have:
- Unmarked or poorly signposted field entrances
- Temporary access roads that differ from standard mapping
- Multiple entrances where only one is designated for competitors
- Limited or no mobile signal for last-minute phone navigation

Having venue navigation available on the car's built-in display is significantly safer and more reliable than phone-based navigation in these conditions.

### Time-critical arrivals
Unlike casual sporting events, competitive equestrian disciplines operate on strict timetables. A competitor who misses their start time is eliminated. Drivers need to see at a glance whether their current travel pace will get them to the venue on time, without unlocking their phone. The "leave by" calculation — which accounts for travel time plus warmup and preparation time — is navigation intelligence specific to this use case.

### Driver safety
Competitors frequently travel long distances (1-3 hours) to reach venues, often towing horse trailers on rural roads. The CarPlay integration eliminates the need to handle a phone while driving to check start times or initiate navigation. All interaction uses CarPlay's driver-optimised templates with large touch targets and minimal distraction.

## CarPlay Templates Used

| Template | Purpose |
|----------|---------|
| `CPPointOfInterestTemplate` | Display competition venues as map pins with start times and travel estimates |
| `CPListTemplate` | Scrollable list of upcoming competitions with venue, date, first start time, and departure guidance |
| `CPMapTemplate` | Map overview of venue locations in the region |
| `CPInformationTemplate` | Competition detail view showing full discipline schedule and venue information |

## Comparable Approved Apps

The TetraTrack CarPlay experience follows the same pattern as approved CarPlay apps in adjacent categories:

- **Parking apps** (SpotHero, ParkWhiz) — Show nearby points of interest with relevant metadata, then navigate to the selected location
- **EV charging apps** (ChargePoint, PlugShare) — Display destination pins on a map with availability information, then route to the selected charger
- **Fueling apps** (GasBuddy) — List nearby locations with contextual data, then provide navigation

TetraTrack applies this identical pattern to competition venues: display relevant locations with time-sensitive metadata, then provide navigation to the selected venue.

## User Base

TetraTrack serves competitors in Pony Club tetrathlon, British Eventing, and affiliated equestrian sports across the UK. These athletes travel to competitions weekly during the season (March–October), making venue navigation a core and frequent use case.

---

## Contact

Darryl Cauldwell
darryl.cauldwell@gmail.com
+44 7817352343
