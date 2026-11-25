"""JSONL output helpers."""

import json
import sys

def print_json(obj):
    sys.stdout.write(json.dumps(obj, sort_keys=True) + "\n")
    sys.stdout.flush()



def print_event(event, payload):
    print_json({"event": event, "payload": payload})
