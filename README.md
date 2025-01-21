# backups unstoppable

Long term goal: a backup service that is uninterruptible because it is a smart contract that is setup once with origin and destination credentials (or their hashes). As long as it is paid, it will continue to run. It is not cancellable. Runs in a TEE environment.

Short term goal: A script that can be run on a server that backs up a directory on that same server.

## Requirements

-   Easy setup on server - single liner.
-   Configurable with .env file
-   Independent reporting on failed / missing backups.
-   Automatic scheduling (e.g.) via cron job:
    -   customers run in parallel
    -   each customers jobs run scheduled
    -   scheduled customer jobs cannot overlap. A new job will not be triggered if an old one overlaps.
-   Storage persistence in filesystem: Each customer has it's own folder
-   Load secrets from infisical
-   rustic implementation

## Get started

1. Install:

    - kubernetes (e.g. with rancher desktop) - needs to be running
    - talosctl
    - helm (with helm-diff plugin installed)
    - helmfile
    - on commandline: botan, tar

2. Clone repo
3. Run unlock on secrets: `cd kubernetes && ./locker.sh unlock <your-passphrase>`
4. Start kubernetes
5. talosctl cluster create
6. helmfile apply

Before every commit, run `./locker.sh lock <your-passphrase>`

## Threat scenarios

**Scenario A** ✅
The attackers have access to a single machine and stop the primary backup mechanism: machine -> server. Discoverable by reporting.

**Scenario B** ❌
The attackers have changed the primary backup mechanism (machine -> server) encryption key to an unknown key.

**Scenario C** ✅
The attackers have full access to the primary backup machine.

## Scheduling

If we have two customers, we will trigger the backup jobs for each customer at the same time. If the backup job from the last time is still running, we don't trigger a new job.

```
|8am          |9am         |10am

✅|__customer1__job1__|     ✅|__customer1__job3__|
              ❌|__customer1__job2__|

✅|__customer2__job1__|
```

Explanation: customer1_job2 is not exectued, as it overlaps with job1.

## Storage persistence

The following storage layout is proposed:

### Hot repo

Stores metadata of rustic on server.
We utilize Mayastor running on kubernetes:

-   Backed by local PV hostpath on development
-   Backed by ZFS or LVM storage on production

### Cold repo

This stores customer data of rustic on ramo:

-   Each customer has his own bucket named after the customer.
-   Every customer can have a multitude of ressources, which are endpoints from which we retrieve the backups

```
customer1/
    ressource1/
    ressource2/
    ...
customer2/
```

### Customer implementation requirements

-   Customer needs to implement FTPS (NOT SFTP!) in passive mode (so that we can mount it in docker)

### Notes

-   Run Talos OS on nodes (if we run our own nodes)
-   k3s for kubernetes (to run kubernetes, not needed if talos OS is running)
-   talosctl to control talos
-   openebs for storage
    -   local pv hostpath for storage in development (no replication)
    -   mayastor for replicated storage in production
-   Use helm to define cronjob (for each customer ressource a dedicated cronjob)
-   Use helmfile to distinguish between development and production environment. (OpenEBS wants different storage settings in dev than in prod).

## Get Started

-   Make sure your k8s cluster is running (i.e. `talosctl cluster create`)
-   Run dev or prod in flux ... (what does that mean?)
-   ...
-   At the end destroy k8s cluster by running `talosctl cluster destroy`
