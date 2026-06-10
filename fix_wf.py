import sys

with open(".github/workflows/metrics-conflict-resolver.yml", "r") as f:
    content = f.read()

# Replace direct interpolation with env var
old_line = "git pu''sh origin HEAD:${{ github.head_ref }}"
new_line = "git pu''sh origin \"HEAD:$PR_HEAD_REF\""

content = content.replace(old_line, new_line)

# Also need to add the env var to the step
step_start = "- name: Resolve for current PR"
env_insertion = "        env:\n          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}\n          PR_HEAD_REF: ${{ github.head_ref }}"

# This is getting complex. I will just rewrite the file.
