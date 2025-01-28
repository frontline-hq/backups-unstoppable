# backups unstoppable

Long term goal: a backup service that is uninterruptible because it is a smart contract that is setup once with origin and destination credentials (or their hashes). As long as it is paid, it will continue to run. It is not cancellable. Runs in a TEE environment.

Short term goal: A script that can be run on a server that backs up a directory on that same server.

## Architecture

We need to run independent cron jobs for every customer.
That's why we run a docker container for every customer x source pairing.

We can either run the docker container based on a cron job set up on the server.
Or we run the cronjob in the container and keep the container running.

It seems that setting up the cron job in the container is a setup that's easier testable.

## Requirements

- Easy setup on server - single liner.
- Configurable with .env file
- Independent reporting on failed / missing backups.
- Automatic scheduling (e.g.) via cron job:
  - customers run in parallel
  - each customers jobs run scheduled
  - scheduled customer jobs cannot overlap. A new job will not be triggered if an old one overlaps.
- Storage persistence in filesystem: Each customer has it's own folder
- Load secrets from infisical
- rustic implementation

## Get started

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

### Cold repo

This stores customer data of rustic on ramo:

- Each customer has his own bucket named after the customer.
- Every customer can have a multitude of ressources, which are endpoints from which we retrieve the backups

```
customer1/
    ressource1/
    ressource2/
    ...
customer2/
```

### Customer implementation requirements

- Customer needs to implement FTPS (NOT SFTP!) in passive mode (so that we can mount it in docker)

### Test strategy

- We run different deployments on test with different commands that we pass into rustic.
- Foremost we want to load up our SFTP server with data, run rustic on it (to our local minio) and then restore the data again. We run the rustic container itself as a test then.
