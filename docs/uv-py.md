# uv-py

[uv-py](../stash/root/usr/local/bin/uv-py) is a script meant to wrap around python, which automatically installs dependencies

It supports
- requirements.txt
- pyproject.toml
- CommunityScrapers [`ensure_requirements`](https://github.com/stashapp/CommunityScrapers/blob/master/scrapers/py_common/deps.py)

To switch to uv-py, switch your python executable path to point to `uv-py`. In System -> Python Executable Path, set it to `/usr/local/bin/uv-py`