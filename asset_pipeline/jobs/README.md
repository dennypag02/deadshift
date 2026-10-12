# DeadShift worker job queue

This folder is the remote queue watched by the local DeadShift worker.

ChatGPT creates immutable YAML files in `jobs/queued/`. The worker pulls the
branch periodically, processes each unseen job once, and records local state in
ignored files on the user's PC.

Example job:

```yaml
job_id: car-suv-20261012-001
asset: car_suv
category: cars
count: 20
positive: "full positive prompt"
negative: "full negative prompt"
```

The worker generates one image at a time even when `count` is 20. Completed
review batches are available locally at `http://127.0.0.1:8765/latest`.
