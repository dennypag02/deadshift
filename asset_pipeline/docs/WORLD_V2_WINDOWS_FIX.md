# Windows runtime follow-up to PR #22

The first actual PC receipt, job 20261016-world-v2-generator-anchor, stopped at
COMFY_PYTHON_DEPENDENCIES_MISSING_NO_PACKAGES_INSTALLED. Zero images were generated
and model installation had not started. Receipt commit 65f470d7c201bc0284b34361f0081e5fa18268ef.

Windows text-mode stdin also added CR to the mktree filename, producing
world_status.json followed by a carriage return. The receipt was recovered by
its exact blob 8d0710d1a7c6130da33f2376601ebf62ef5a96c9, not treated as a missing job.

Fixes:
- Git plumbing stdin is UTF-8 bytes, never Windows text-mode translated.
- A read-only Windows process query finds only ComfyUI Python executables. It
  does not return/log command lines, terminate processes, install packages, or
  elevate privileges. The running server interpreter is preferred over guessed
  adjacent virtual environments. The configured override still takes priority.
- Runtime receipts report installed package versions and exact missing packages
  without executable paths or command lines. A genuine missing dependency stops
  with no package installation.

Five new tests plus the existing 61 passed locally. CI must verify these before
merge to the worker branch. The failed job remains preserved and processed; a
new uniquely named job may retry after deployment. No prompt had been submitted,
so this retry cannot duplicate a generated image from the failed first attempt.
