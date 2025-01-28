# Running openebs locally with tilt, helmfile and kind

## Requirements

- Running docker instance with Docker Desktop (NOT! Rancher desktop e.g.)
- Install packages `kind`, `ctlptl`, `tilt`

## Get started

1. git clone
2. `cd kubernetes`
3. `ctlptl apply -f ctlptl.yaml`
4. `tilt up`

Then visit tilt at http://localhost:10350/
