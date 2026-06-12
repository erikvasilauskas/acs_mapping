# Kalamazoo City Commuter-Shed Research

This folder develops data-driven alternatives to fixed Kalamazoo boundaries.

The starting script uses LEHD Origin-Destination Employment Statistics (LODES)
to aggregate block-to-block job flows into tract-level measures tied to
Kalamazoo city:

- inbound flows: workers living in a tract and working in Kalamazoo city
- outbound flows: workers living in Kalamazoo city and working in a tract
- bidirectional flows: inbound plus outbound ties

LODES is not an ACS sample table. It is a Census LEHD public-use data product
based on linked administrative employment records and modeling. The Michigan
LODES8 main all-jobs OD files currently available in the public directory run
through 2021.

## Starting Shed Rule

The initial tract classification uses these working thresholds:

- Kalamazoo city: any tract intersecting a Kalamazoo city 2020 block in the
  LODES crosswalk
- Inbound shed: at least 50 jobs from tract residents to Kalamazoo city, or at
  least 5 percent of the tract's resident jobs working in Kalamazoo city
- Outbound shed: at least 50 jobs from Kalamazoo city residents to the tract, or
  at least 5 percent of the tract's workplace jobs held by Kalamazoo city
  residents
- Bidirectional tie: remaining tracts with at least 50 combined inbound and
  outbound jobs, or a combined commuter score of at least 0.05

These are starting thresholds for review, not final research definitions.

The commuter score is:

`inbound_share_to_kalamazoo + outbound_share_from_kalamazoo`

where inbound share is the share of a tract's resident jobs working in
Kalamazoo city, and outbound share is the share of a tract's workplace jobs held
by Kalamazoo city residents.
