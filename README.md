# TheBiggerInterview dataset

TheBiggerInterview is an investigation scenario detailed in [the related blog article](https://unsecure.sh/blog/agentic-soc-scenario/). This repository holds its dataset, as well as everything needed to ingest it in a local Splunk instance. Of course, you may ingest this dataset in the SIEM of your choice.

The dataset is 2.2 million events over about 47 hours, 203 MB compressed here and roughly 3.4 GB once indexed.

## Using Splunk 

### Requirements

- Docker, with roughly 15 GB of free disk.
- Around ten minutes to ingest the full dataset.

### Run it

```bash
docker build -t splunk-lab .

docker run -d --name splunk-lab -p 8000:8000 \
  -e SPLUNK_START_ARGS='--accept-license --accept-sgt-current-at-splunk-com' \
  -e SPLUNK_GENERAL_TERMS='--accept-sgt-current-at-splunk-com' \
  -e SPLUNK_PASSWORD='ChooseAStrongPw1' \
  splunk-lab
```

Then open <http://localhost:8000> and log in as `admin` with the password you
chose. It must be at least 8 characters or Splunk refuses to start.

### Checking the ingest

```bash
docker exec -u splunk splunk-lab /opt/splunk/bin/splunk search \
  '| tstats count where index=investigation earliest=0 latest=+10y by sourcetype' \
  -auth admin:ChooseAStrongPw1
```

Ingest is complete when the counts stop changing and match this:

| sourcetype | events | window (UTC) |
|---|---|---|
| `aws:cloudtrail` | 43,027 | 2026-08-11 14:20 → 2026-08-13 12:44 |
| `aws:eks:audit` | 1,999,440 | 2026-08-11 13:54 → 2026-08-13 12:44 |
| `crowdstrike:falcon:edr` | 194,125 | 2026-08-11 14:21 → 2026-08-13 12:44 |
| `github:cloud:audit` | 393 | 2026-08-11 14:25 → 2026-08-13 12:19 |
| **total** | **2,236,985** | |

### The data

Everything is in one index, `investigation`, with one sourcetype per source:

| sourcetype | what it is | `host` |
|---|---|---|
| `aws:cloudtrail` | AWS CloudTrail records | `sim-cloudtrail` |
| `aws:eks:audit` | Kubernetes API server audit logs | `sim-eks-apiserver` |
| `crowdstrike:falcon:edr` | CrowdStrike events | `sim-edr-sensor` |
| `github:cloud:audit` | GitHub organization audit logs | `sim-github-audit` |

Every event is raw JSON, field-extracted by Splunk's own search-time JSON
handling, so there are no add-ons to install:

```spl
index=investigation sourcetype=aws:cloudtrail eventName=CreateFunction
| table _time, userIdentity.arn, requestParameters.functionName

index=investigation sourcetype=aws:eks:audit verb=create objectRef.resource=pods
| table _time, user.username, objectRef.namespace

index=investigation sourcetype=crowdstrike:falcon:edr
| stats count by event_simpleName
```

## Licensing

This repository holds a Dockerfile, Splunk configuration, and log data. Two
things to know before you build:

- **Index inside the 60-day Enterprise Trial.** A fresh container starts a
  trial, which has no ingest cap. When it ends Splunk converts to the free
  licence, which caps indexing at 500 MB/day and would refuse this dataset.
  Continued use past the trial term is expected to be licensed.
- Splunk is a trademark of Splunk LLC; CrowdStrike and Falcon of CrowdStrike,
  Inc.; AWS, CloudTrail and EKS of Amazon.com, Inc. or its affiliates;
  Kubernetes of The Linux Foundation; GitHub of GitHub, Inc. This project is not
  affiliated with, sponsored by or endorsed by any of them, and uses those names
  only to describe the origin and format of the log data.

Three licences apply, to three different things:

| | Licence | What it means here |
|---|---|---|
| Code — `Dockerfile`, `entrypoint.sh`, `conf/` | [MIT](LICENSE) | do as you like |
| Data — `logs/` | [CC BY-NC-SA 4.0](LICENSE-DATA) | credit, **no commercial use**, share alike |
| Splunk Enterprise | Splunk General Terms | not included; you accept them yourself |

The dataset is the restrictive one. Selling access to it, or selling a course or
an assessment product built on it, is not permitted; using it to train or
interview your own staff is fine. "Non-commercial" has no sharp legal boundary,
so if your use sits near the line, ask rather than assume.

## Troubleshooting

**The container exits immediately.** Almost always the password: it must be at
least 8 characters. `docker logs splunk-lab` will say so.

**Searches return nothing.** Set the time range to **All time**.

**`docker exec` says the pid file is unreadable.** You left out `-u splunk`.

**A sourcetype is missing or the count is short.** Indexing is probably still
running; archived files are processed one at a time. To confirm Splunk is reading
them:

```bash
docker exec -u splunk splunk-lab /opt/splunk/bin/splunk search \
  'index=_internal source=*splunkd.log* (component=ArchiveProcessor OR component=TailReader) | tail 40' \
  -auth admin:ChooseAStrongPw1
```

**Every event has the same timestamp, or they are all days apart.** The
`props.conf` timestamp settings are not being applied — check that
`conf/props.conf` is in the image and that its stanza names match the
sourcetypes in `conf/inputs.conf`.
