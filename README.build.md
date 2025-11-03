## Python package build notes

### Prerequisites

```bash
python -m pip install --upgrade build
```

Increase the version number in `setup.py` before building so that package indexes and dependency managers can detect the
new release.

### Create a source and wheel distribution

```bash
rm -rf dist/*
rm -rf build/lib/oliver_framework/*
cp -rf python/* build/lib/oliver_framework/
python -m build
git add *
git commit -m LatestBuild#
git push
# Upgrade in target
pip install --upgrade --force-reinstall git+https://github.com/jufist/oliver-framework.git
```

The `python/` directory is declared as the package source in `setup.py`, so no additional file copies are required.

### Publish the build

```bash
git add .
git commit -m "Build release"
git push
```

To test the package locally before publishing, install it in a virtual environment:

```bash
python -m venv .venv
source .venv/bin/activate
python -m pip install --upgrade dist/*.whl
```

### Editable installs for development

```bash
python -m pip install --upgrade pip
python -m pip install --upgrade -e .
```

Reinstall the package in downstream projects by activating the appropriate environment and running:

```bash
python -m pip install --upgrade git+https://github.com/jufist/oliver-framework.git
```
