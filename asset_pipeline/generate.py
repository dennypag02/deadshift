#!/usr/bin/env python3
"""Stable worker entrypoint; legacy jobs unchanged, world v2 is explicitly opted in."""
from pathlib import Path
import sys
import yaml
from generate_legacy import *  # Preserve the existing public helper API and CLI.
import generate_legacy as legacy


def main():
    args = legacy.parse_args()
    if args.job_file is not None:
        job = yaml.safe_load(args.job_file.read_text(encoding='utf-8'))
        if isinstance(job, dict) and job.get('pipeline') == 'world_v2':
            from world_v2.runner import run
            job['job_id'] = str(job.get('job_id') or args.job_file.stem)
            run(job, dry_run=args.dry_run)
            return
    legacy.main()


if __name__ == '__main__':
    main()
