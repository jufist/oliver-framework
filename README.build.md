python -m pip install --upgrade build

# Increase version at setup.py

```
rm -rf dist/*
rm -rf build/lib/oliver_framework/*;
cp -rf python/* build/lib/oliver_framework/
python -m build
pip install --upgrade git+https://github.com/jufist/oliver-framework.git
```
